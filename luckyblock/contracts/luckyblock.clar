;; LuckyBlock - A verifiable on-chain lottery system with multiple winners
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
(define-constant ERR-INVALID-WINNERS (err u109))
(define-constant ERR-TOO-MANY-WINNERS (err u110))
(define-constant ERR-INVALID-TICKET-PRICE (err u111))
(define-constant ERR-INVALID-MIN-PLAYERS (err u112))
(define-constant ERR-INVALID-MIN-BLOCKS (err u113))

;; Constants for input validation
(define-constant MIN-TICKET-PRICE u100000)  ;; 0.1 STX
(define-constant MAX-TICKET-PRICE u100000000)  ;; 100 STX
(define-constant MAX-MIN-PLAYERS u20)  ;; Maximum value for minimum players
(define-constant MIN-BLOCKS-LOWER u50)  ;; Minimum value for min-blocks
(define-constant MIN-BLOCKS-UPPER u1000)  ;; Maximum value for min-blocks

;; Data variables
(define-data-var current-lottery-id uint u0)
(define-data-var lottery-start-height uint u0)
(define-data-var ticket-price uint u1000000) ;; 1 STX default
(define-data-var min-players uint u2)
(define-data-var min-blocks uint u100)
(define-data-var winner-count uint u3) ;; Default number of winners
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
        winners: (list 10 {winner: principal, prize: uint}),
        status: (string-ascii 20),
        random-seed: uint
    }
)

(define-map participant-tickets
    {lottery-id: uint, participant: principal}
    uint
)

;; Helper functions
(define-private (min-of (a uint) (b uint))
    (if (<= a b)
        a
        b))

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

(define-private (calculate-prize (total-pot uint) (position uint) (total-winners uint))
    (let (
        (base-prize (/ total-pot total-winners))
        (bonus (if (is-eq position u0) 
            (mod total-pot total-winners)
            u0
        ))
    )
        (+ base-prize bonus)
    )
)

(define-private (get-next-winner 
    (winners (list 10 {winner: principal, prize: uint}))
    (participants (list 50 principal))
    (seed uint)
    (total-pot uint)
    (total-winners uint))
    (let (
        (participant-count (len participants))
        (selected-index (get-random-number seed participant-count))
        (winner (unwrap! (element-at participants selected-index) winners))
        (current-count (len winners))
    )
        (if (>= current-count total-winners)
            winners
            (unwrap! 
                (as-max-len? 
                    (append winners {
                        winner: winner,
                        prize: (calculate-prize total-pot current-count total-winners)
                    })
                    u10
                )
                winners
            )
        )
    )
)

(define-private (select-winners (lottery-id uint) (participants (list 50 principal)) (total-pot uint))
    (let (
        (participant-count (len participants))
        (winners-needed (min-of (var-get winner-count) participant-count))
        (initial-seed (generate-random-seed))
    )
        (if (> winners-needed u0)
            (ok (fold add-winner
                (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)
                {
                    winners: (list),
                    candidates: participants,
                    seed: initial-seed,
                    needed: winners-needed,
                    pot: total-pot
                }
            ))
            (err u100)
        )
    )
)

(define-private (add-winner
    (index uint)
    (state {
        winners: (list 10 {winner: principal, prize: uint}),
        candidates: (list 50 principal),
        seed: uint,
        needed: uint,
        pot: uint
    }))
    (let (
        (current-winners (get winners state))
        (remaining-candidates (get candidates state))
        (current-count (len current-winners))
    )
        (if (>= current-count (get needed state))
            state
            {
                winners: (get-next-winner 
                    current-winners 
                    remaining-candidates 
                    (+ (get seed state) index)
                    (get pot state)
                    (get needed state)
                ),
                candidates: remaining-candidates,
                seed: (get seed state),
                needed: (get needed state),
                pot: (get pot state)
            }
        )
    )
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
                    winners: (list),
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
                    winners: (get winners current-lottery),
                    status: (get status current-lottery),
                    random-seed: (get random-seed current-lottery)
                }
            )
            (ok true)
        )
    )
)

(define-public (draw-winners)
    (let (
        (lottery-id (var-get current-lottery-id))
        (current-lottery (unwrap! (map-get? lotteries lottery-id) ERR-NO-LOTTERY-ACTIVE))
        (participants (get participants current-lottery))
        (participant-count (len participants))
        (winners-result (try! (select-winners lottery-id participants (get total-pot current-lottery))))
    )
        (begin
            (asserts! (>= block-height (+ (get start-block current-lottery) (var-get min-blocks))) ERR-TOO-EARLY)
            (asserts! (>= participant-count (var-get min-players)) ERR-NO-PARTICIPANTS)
            (asserts! (is-eq (get status current-lottery) "active") ERR-LOTTERY-ENDED)
            
            (let (
                (final-winners (get winners winners-result))
            )
                (begin
                    ;; Update lottery with winners
                    (map-set lotteries lottery-id
                        (merge current-lottery 
                            {
                                winners: final-winners,
                                status: "completed",
                                random-seed: (var-get last-random-seed)
                            }
                        )
                    )
                    
                    ;; Transfer prizes to winners
                    (map transfer-prize final-winners)
                    
                    (ok final-winners)
                )
            )
        )
    )
)

(define-private (transfer-prize (winner {winner: principal, prize: uint}))
    (as-contract (stx-transfer? 
        (get prize winner)
        tx-sender 
        (get winner winner)
    ))
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

(define-read-only (get-winner-count)
    (var-get winner-count)
)

(define-read-only (get-last-random-seed)
    (var-get last-random-seed)
)

;; Admin functions
(define-public (set-ticket-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (and 
            (>= new-price MIN-TICKET-PRICE)
            (<= new-price MAX-TICKET-PRICE)
        ) ERR-INVALID-TICKET-PRICE)
        (var-set ticket-price new-price)
        (ok true)
    )
)

(define-public (set-min-players (new-min uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (and 
            (> new-min u0)
            (<= new-min MAX-MIN-PLAYERS)
        ) ERR-INVALID-MIN-PLAYERS)
        (var-set min-players new-min)
        (ok true)
    )
)

(define-public (set-min-blocks (new-min uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (and 
            (>= new-min MIN-BLOCKS-LOWER)
            (<= new-min MIN-BLOCKS-UPPER)
        ) ERR-INVALID-MIN-BLOCKS)
        (var-set min-blocks new-min)
        (ok true)
    )
)

(define-public (set-winner-count (new-count uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (<= new-count u10) ERR-TOO-MANY-WINNERS)
        (asserts! (> new-count u0) ERR-INVALID-WINNERS)
        (var-set winner-count new-count)
        (ok true)
    )
)