(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-funds (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-not-authorized (err u104))
(define-constant err-already-exists (err u105))
(define-constant err-invalid-shares (err u106))
(define-constant err-livestock-sold (err u107))

(define-data-var next-livestock-id uint u1)
(define-data-var next-expense-id uint u1)

(define-map livestock
  { livestock-id: uint }
  {
    owner: principal,
    name: (string-ascii 50),
    total-shares: uint,
    price-per-share: uint,
    shares-sold: uint,
    total-revenue: uint,
    total-expenses: uint,
    is-sold: bool,
    created-at: uint
  }
)

(define-map livestock-shareholders
  { livestock-id: uint, shareholder: principal }
  { shares: uint }
)

(define-map shareholder-livestock
  { shareholder: principal, livestock-id: uint }
  { shares: uint }
)

(define-map livestock-expenses
  { expense-id: uint }
  {
    livestock-id: uint,
    amount: uint,
    description: (string-ascii 100),
    created-at: uint
  }
)

(define-map livestock-revenue
  { livestock-id: uint }
  { total-amount: uint, last-updated: uint }
)

(define-public (create-livestock (name (string-ascii 50)) (total-shares uint) (price-per-share uint))
  (let
    (
      (livestock-id (var-get next-livestock-id))
    )
    (asserts! (> total-shares u0) err-invalid-shares)
    (asserts! (> price-per-share u0) err-invalid-amount)
    (map-set livestock
      { livestock-id: livestock-id }
      {
        owner: tx-sender,
        name: name,
        total-shares: total-shares,
        price-per-share: price-per-share,
        shares-sold: u0,
        total-revenue: u0,
        total-expenses: u0,
        is-sold: false,
        created-at: stacks-block-height
      }
    )
    (var-set next-livestock-id (+ livestock-id u1))
    (ok livestock-id)
  )
)

(define-public (buy-shares (livestock-id uint) (shares uint))
  (let
    (
      (livestock-data (unwrap! (map-get? livestock { livestock-id: livestock-id }) err-not-found))
      (total-cost (* shares (get price-per-share livestock-data)))
      (current-shares (default-to u0 (get shares (map-get? livestock-shareholders { livestock-id: livestock-id, shareholder: tx-sender }))))
    )
    (asserts! (> shares u0) err-invalid-shares)
    (asserts! (<= (+ (get shares-sold livestock-data) shares) (get total-shares livestock-data)) err-insufficient-funds)
    (asserts! (not (get is-sold livestock-data)) err-livestock-sold)
    
    (try! (stx-transfer? total-cost tx-sender (get owner livestock-data)))
    
    (map-set livestock-shareholders
      { livestock-id: livestock-id, shareholder: tx-sender }
      { shares: (+ current-shares shares) }
    )
    
    (map-set shareholder-livestock
      { shareholder: tx-sender, livestock-id: livestock-id }
      { shares: (+ current-shares shares) }
    )
    
    (map-set livestock
      { livestock-id: livestock-id }
      (merge livestock-data { shares-sold: (+ (get shares-sold livestock-data) shares) })
    )
    
    (ok true)
  )
)

(define-public (add-expense (livestock-id uint) (amount uint) (description (string-ascii 100)))
  (let
    (
      (livestock-data (unwrap! (map-get? livestock { livestock-id: livestock-id }) err-not-found))
      (expense-id (var-get next-expense-id))
    )
    (asserts! (is-eq tx-sender (get owner livestock-data)) err-not-authorized)
    (asserts! (> amount u0) err-invalid-amount)
    
    (map-set livestock-expenses
      { expense-id: expense-id }
      {
        livestock-id: livestock-id,
        amount: amount,
        description: description,
        created-at: stacks-block-height
      }
    )
    
    (map-set livestock
      { livestock-id: livestock-id }
      (merge livestock-data { total-expenses: (+ (get total-expenses livestock-data) amount) })
    )
    
    (var-set next-expense-id (+ expense-id u1))
    (ok expense-id)
  )
)

(define-public (add-revenue (livestock-id uint) (amount uint))
  (let
    (
      (livestock-data (unwrap! (map-get? livestock { livestock-id: livestock-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender (get owner livestock-data)) err-not-authorized)
    (asserts! (> amount u0) err-invalid-amount)
    
    (map-set livestock-revenue
      { livestock-id: livestock-id }
      { total-amount: amount, last-updated: stacks-block-height }
    )
    
    (map-set livestock
      { livestock-id: livestock-id }
      (merge livestock-data { total-revenue: (+ (get total-revenue livestock-data) amount) })
    )
    
    (ok true)
  )
)

(define-public (sell-livestock (livestock-id uint) (sale-price uint))
  (let
    (
      (livestock-data (unwrap! (map-get? livestock { livestock-id: livestock-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender (get owner livestock-data)) err-not-authorized)
    (asserts! (> sale-price u0) err-invalid-amount)
    (asserts! (not (get is-sold livestock-data)) err-livestock-sold)
    
    (map-set livestock
      { livestock-id: livestock-id }
      (merge livestock-data { 
        is-sold: true,
        total-revenue: (+ (get total-revenue livestock-data) sale-price)
      })
    )
    
    (ok true)
  )
)

(define-public (claim-profits (livestock-id uint))
  (let
    (
      (livestock-data (unwrap! (map-get? livestock { livestock-id: livestock-id }) err-not-found))
      (shareholder-data (unwrap! (map-get? livestock-shareholders { livestock-id: livestock-id, shareholder: tx-sender }) err-not-authorized))
      (net-profit (if (> (get total-revenue livestock-data) (get total-expenses livestock-data))
                    (- (get total-revenue livestock-data) (get total-expenses livestock-data))
                    u0))
      (shareholder-profit (/ (* net-profit (get shares shareholder-data)) (get shares-sold livestock-data)))
    )
    (asserts! (get is-sold livestock-data) err-not-authorized)
    (asserts! (> shareholder-profit u0) err-insufficient-funds)
    
    (try! (as-contract (stx-transfer? shareholder-profit tx-sender tx-sender)))
    
    (map-delete livestock-shareholders { livestock-id: livestock-id, shareholder: tx-sender })
    (map-delete shareholder-livestock { shareholder: tx-sender, livestock-id: livestock-id })
    
    (ok shareholder-profit)
  )
)

(define-read-only (get-livestock (livestock-id uint))
  (map-get? livestock { livestock-id: livestock-id })
)

(define-read-only (get-shareholder-shares (livestock-id uint) (shareholder principal))
  (map-get? livestock-shareholders { livestock-id: livestock-id, shareholder: shareholder })
)

(define-read-only (get-livestock-expense (expense-id uint))
  (map-get? livestock-expenses { expense-id: expense-id })
)

(define-read-only (get-livestock-revenue (livestock-id uint))
  (map-get? livestock-revenue { livestock-id: livestock-id })
)

(define-read-only (calculate-net-profit (livestock-id uint))
  (let
    (
      (livestock-data (unwrap! (map-get? livestock { livestock-id: livestock-id }) err-not-found))
    )
    (ok (if (> (get total-revenue livestock-data) (get total-expenses livestock-data))
          (- (get total-revenue livestock-data) (get total-expenses livestock-data))
          u0))
  )
)

(define-read-only (calculate-shareholder-profit (livestock-id uint) (shareholder principal))
  (let
    (
      (livestock-data (unwrap! (map-get? livestock { livestock-id: livestock-id }) err-not-found))
      (shareholder-data (unwrap! (map-get? livestock-shareholders { livestock-id: livestock-id, shareholder: shareholder }) err-not-authorized))
      (net-profit (if (> (get total-revenue livestock-data) (get total-expenses livestock-data))
                    (- (get total-revenue livestock-data) (get total-expenses livestock-data))
                    u0))
    )
    (ok (/ (* net-profit (get shares shareholder-data)) (get shares-sold livestock-data)))
  )
)

(define-read-only (get-available-shares (livestock-id uint))
  (let
    (
      (livestock-data (unwrap! (map-get? livestock { livestock-id: livestock-id }) err-not-found))
    )
    (ok (- (get total-shares livestock-data) (get shares-sold livestock-data)))
  )
)
