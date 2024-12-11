;; LuckyBlock - A verifiable on-chain lottery system
;; A fair, decentralized lottery using block information for randomness

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-LOTTERY-IN-PROGRESS (err u101))
(define-constant ERR-NO-LOTTERY-ACTIVE (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-ALREADY-PARTICIPATED (err u104))
(define-constant ERR-NO-PARTICIPANTS (err u105))
(define-constant ERR-TOO-EARLY (err u106))
(define-constant ERR-INVALID-AMOUNT (err u107))
(define-constant ERR-LOTTERY-ENDED (err u108))

;; Data variables
(define-data-var current-lottery-id uint u0)
(define-data-var lottery-start-height uint u0)
(define-data-var ticket-price uint u1000000) ;; 1 STX default
(define-data-var min-players uint u2)
(define-data-var min-blocks uint u100)
(define-data-var contract-owner principal tx-sender)
(define-data-var last-random-seed uint u0)

;; Data maps
(define-map lotteries
    uint 
    {
        participants: (list 50 principal),
        tickets: (list 50 uint),
        total-pot: uint,
        start-block: uint,
        end-block: uint,
        winner: (optional principal),
        status: (string-ascii 20),
        random-seed: uint
    }
)

(define-map participant-tickets
    {lottery-id: uint, participant: principal}
    uint
)

(define-map random-seeds
    uint
    {
        block-height: uint,
        block-time: uint,
        participant-count: uint
    }
)

;; Private functions
(define-private (can-start-lottery)
    (let (
        (current-lottery (unwrap! (map-get? lotteries (var-get current-lottery-id)) false))
    )
        (or 
            (is-eq (get status current-lottery) "completed")
            (is-eq (get status current-lottery) "cancelled")
        )
    )
)

(define-private (is-active)
    (let (
        (current-lottery (unwrap! (map-get? lotteries (var-get current-lottery-id)) false))
    )
        (and
            (is-eq (get status current-lottery) "active")
            (>= block-height (get start-block current-lottery))
            (<= block-height (get end-block current-lottery))
        )
    )
)

(define-private (generate-random-seed)
    (let (
        (current-time (default-to u0 (get-block-info? time block-height)))
        (prev-time (default-to u0 (get-block-info? time (- block-height u1))))
    )
        (mod (+ (* current-time u113) (* prev-time u151)) u1000000000)
    )
)

(define-private (get-random-number (seed uint) (max uint))
    (mod seed max)
)

;; Public functions
(define-public (initialize-lottery)
    (let (
        (new-lottery-id (+ (var-get current-lottery-id) u1))
        (init-seed (generate-random-seed))
    )
        (begin
            (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
            (asserts! (can-start-lottery) ERR-LOTTERY-IN-PROGRESS)
            
            (map-set lotteries new-lottery-id 
                {
                    participants: (list),
                    tickets: (list),
                    total-pot: u0,
                    start-block: block-height,
                    end-block: (+ block-height (var-get min-blocks)),
                    winner: none,
                    status: "active",
                    random-seed: init-seed
                }
            )
            (var-set current-lottery-id new-lottery-id)
            (var-set lottery-start-height block-height)
            (var-set last-random-seed init-seed)
            (ok new-lottery-id)
        )
    )
)

(define-public (buy-ticket)
    (let (
        (lottery-id (var-get current-lottery-id))
        (current-lottery (unwrap! (map-get? lotteries lottery-id) ERR-NO-LOTTERY-ACTIVE))
        (current-participants (get participants current-lottery))
        (current-tickets (get tickets current-lottery))
    )
        (begin
            (asserts! (is-active) ERR-NO-LOTTERY-ACTIVE)
            (asserts! (>= (stx-get-balance tx-sender) (var-get ticket-price)) ERR-INSUFFICIENT-FUNDS)
            
            ;; Transfer STX to contract
            (try! (stx-transfer? (var-get ticket-price) tx-sender (as-contract tx-sender)))
            
            ;; Update participant tickets
            (map-set participant-tickets 
                {lottery-id: lottery-id, participant: tx-sender}
                (+ (default-to u0 (map-get? participant-tickets 
                    {lottery-id: lottery-id, participant: tx-sender})) u1)
            )
            
            ;; Update lottery data
            (map-set lotteries lottery-id
                {
                    participants: (unwrap! (as-max-len? 
                        (append current-participants tx-sender) u50) ERR-LOTTERY-ENDED),
                    tickets: (unwrap! (as-max-len? 
                        (append current-tickets (len current-tickets)) u50) ERR-LOTTERY-ENDED),
                    total-pot: (+ (get total-pot current-lottery) (var-get ticket-price)),
                    start-block: (get start-block current-lottery),
                    end-block: (get end-block current-lottery),
                    winner: (get winner current-lottery),
                    status: (get status current-lottery),
                    random-seed: (get random-seed current-lottery)
                }
            )
            (ok true)
        )
    )
)

(define-public (draw-winner)
    (let (
        (lottery-id (var-get current-lottery-id))
        (current-lottery (unwrap! (map-get? lotteries lottery-id) ERR-NO-LOTTERY-ACTIVE))
        (participants (get participants current-lottery))
        (participant-count (len participants))
        (final-seed (generate-random-seed))
    )
        (begin
            (asserts! (>= block-height (+ (get start-block current-lottery) (var-get min-blocks))) ERR-TOO-EARLY)
            (asserts! (>= participant-count (var-get min-players)) ERR-NO-PARTICIPANTS)
            (asserts! (is-eq (get status current-lottery) "active") ERR-LOTTERY-ENDED)
            
            (let (
                (selected-index (get-random-number final-seed participant-count))
                (winner (unwrap! (element-at participants selected-index) ERR-NO-PARTICIPANTS))
            )
                (begin
                    ;; Update lottery with winner
                    (map-set lotteries lottery-id
                        (merge current-lottery 
                            {
                                winner: (some winner),
                                status: "completed",
                                random-seed: final-seed
                            }
                        )
                    )
                    
                    ;; Transfer prize to winner
                    (try! (as-contract (stx-transfer? 
                        (get total-pot current-lottery)
                        tx-sender 
                        winner
                    )))
                    
                    (var-set last-random-seed final-seed)
                    (ok winner)
                )
            )
        )
    )
)

;; Read-only functions
(define-read-only (get-lottery-info (lottery-id uint))
    (map-get? lotteries lottery-id)
)

(define-read-only (get-participant-tickets (lottery-id uint) (participant principal))
    (map-get? participant-tickets {lottery-id: lottery-id, participant: participant})
)

(define-read-only (get-current-lottery)
    (get-lottery-info (var-get current-lottery-id))
)

(define-read-only (get-ticket-price)
    (var-get ticket-price)
)

(define-read-only (get-last-random-seed)
    (var-get last-random-seed)
)

;; Admin functions
(define-public (set-ticket-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set ticket-price new-price)
        (ok true)
    )
)

(define-public (set-min-players (new-min uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set min-players new-min)
        (ok true)
    )
)

(define-public (set-min-blocks (new-min uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set min-blocks new-min)
        (ok true)
    )
)