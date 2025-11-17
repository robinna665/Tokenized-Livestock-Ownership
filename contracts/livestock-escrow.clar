(define-constant err-not-authorized (err u600))
(define-constant err-not-found (err u601))
(define-constant err-invalid-amount (err u602))
(define-constant err-escrow-active (err u603))
(define-constant err-escrow-expired (err u604))
(define-constant err-already-completed (err u605))
(define-constant err-deadline-not-reached (err u606))

(define-data-var next-escrow-id uint u1)

(define-map escrow-agreements
  { escrow-id: uint }
  {
    livestock-id: uint,
    seller: principal,
    buyer: principal,
    total-amount: uint,
    amount-deposited: uint,
    deadline: uint,
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map escrow-milestones
  { escrow-id: uint, milestone: uint }
  { amount: uint, completed: bool, verified-at: uint }
)

(define-public (create-escrow (livestock-id uint) (buyer principal) (total-amount uint) (duration uint))
  (let
    (
      (escrow-id (var-get next-escrow-id))
    )
    (asserts! (> total-amount u0) err-invalid-amount)
    (asserts! (> duration u0) err-invalid-amount)
    
    (map-set escrow-agreements
      { escrow-id: escrow-id }
      {
        livestock-id: livestock-id,
        seller: tx-sender,
        buyer: buyer,
        total-amount: total-amount,
        amount-deposited: u0,
        deadline: (+ stacks-block-height duration),
        status: "pending",
        created-at: stacks-block-height
      }
    )
    
    (var-set next-escrow-id (+ escrow-id u1))
    (ok escrow-id)
  )
)

(define-public (deposit-funds (escrow-id uint) (amount uint))
  (let
    (
      (escrow-data (unwrap! (map-get? escrow-agreements { escrow-id: escrow-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender (get buyer escrow-data)) err-not-authorized)
    (asserts! (is-eq (get status escrow-data) "pending") err-escrow-active)
    (asserts! (<= (+ (get amount-deposited escrow-data) amount) (get total-amount escrow-data)) err-invalid-amount)
    (asserts! (< stacks-block-height (get deadline escrow-data)) err-escrow-expired)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set escrow-agreements
      { escrow-id: escrow-id }
      (merge escrow-data { 
        amount-deposited: (+ (get amount-deposited escrow-data) amount),
        status: (if (is-eq (+ (get amount-deposited escrow-data) amount) (get total-amount escrow-data)) "funded" "pending")
      })
    )
    
    (ok true)
  )
)

(define-public (complete-transfer (escrow-id uint))
  (let
    (
      (escrow-data (unwrap! (map-get? escrow-agreements { escrow-id: escrow-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender (get seller escrow-data)) err-not-authorized)
    (asserts! (is-eq (get status escrow-data) "funded") err-escrow-active)
    (asserts! (< stacks-block-height (get deadline escrow-data)) err-escrow-expired)
    
    (try! (as-contract (stx-transfer? (get total-amount escrow-data) tx-sender (get seller escrow-data))))
    
    (map-set escrow-agreements
      { escrow-id: escrow-id }
      (merge escrow-data { status: "completed" })
    )
    
    (ok true)
  )
)

(define-public (cancel-escrow (escrow-id uint))
  (let
    (
      (escrow-data (unwrap! (map-get? escrow-agreements { escrow-id: escrow-id }) err-not-found))
    )
    (asserts! (or (is-eq tx-sender (get seller escrow-data)) (is-eq tx-sender (get buyer escrow-data))) err-not-authorized)
    (asserts! (not (is-eq (get status escrow-data) "completed")) err-already-completed)
    
    (if (> (get amount-deposited escrow-data) u0)
      (try! (as-contract (stx-transfer? (get amount-deposited escrow-data) tx-sender (get buyer escrow-data))))
      true
    )
    
    (map-set escrow-agreements
      { escrow-id: escrow-id }
      (merge escrow-data { status: "cancelled" })
    )
    
    (ok true)
  )
)

(define-public (extend-deadline (escrow-id uint) (additional-blocks uint))
  (let
    (
      (escrow-data (unwrap! (map-get? escrow-agreements { escrow-id: escrow-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender (get seller escrow-data)) err-not-authorized)
    (asserts! (not (is-eq (get status escrow-data) "completed")) err-already-completed)
    (asserts! (> additional-blocks u0) err-invalid-amount)
    
    (map-set escrow-agreements
      { escrow-id: escrow-id }
      (merge escrow-data { deadline: (+ (get deadline escrow-data) additional-blocks) })
    )
    
    (ok true)
  )
)

(define-read-only (get-escrow (escrow-id uint))
  (map-get? escrow-agreements { escrow-id: escrow-id })
)

(define-read-only (get-escrow-status (escrow-id uint))
  (let
    (
      (escrow-data (unwrap! (map-get? escrow-agreements { escrow-id: escrow-id }) err-not-found))
    )
    (ok {
      status: (get status escrow-data),
      funded: (is-eq (get amount-deposited escrow-data) (get total-amount escrow-data)),
      expired: (>= stacks-block-height (get deadline escrow-data)),
      completion-percent: (/ (* (get amount-deposited escrow-data) u100) (get total-amount escrow-data))
    })
  )
)
