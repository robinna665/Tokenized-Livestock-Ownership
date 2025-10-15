(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u500))
(define-constant err-not-found (err u501))
(define-constant err-invalid-amount (err u502))
(define-constant err-rights-sold (err u503))
(define-constant err-not-for-sale (err u504))
(define-constant err-listing-expired (err u505))

(define-data-var next-rights-id uint u1)

(define-map breeding-rights
  { rights-id: uint }
  {
    livestock-id: uint,
    issuer: principal,
    holder: principal,
    breeding-cycles: uint,
    cycles-used: uint,
    offspring-share-percent: uint,
    active: bool,
    issued-at: uint
  }
)

(define-map rights-listings
  { rights-id: uint }
  {
    seller: principal,
    price: uint,
    expiry: uint,
    active: bool
  }
)

(define-map livestock-rights-registry
  { livestock-id: uint, holder: principal }
  { rights-count: uint }
)

(define-public (issue-breeding-rights (livestock-id uint) (breeding-cycles uint) (offspring-share-percent uint))
  (let
    (
      (rights-id (var-get next-rights-id))
    )
    (asserts! (> breeding-cycles u0) err-invalid-amount)
    (asserts! (and (>= offspring-share-percent u1) (<= offspring-share-percent u100)) err-invalid-amount)
    
    (map-set breeding-rights
      { rights-id: rights-id }
      {
        livestock-id: livestock-id,
        issuer: tx-sender,
        holder: tx-sender,
        breeding-cycles: breeding-cycles,
        cycles-used: u0,
        offspring-share-percent: offspring-share-percent,
        active: true,
        issued-at: stacks-block-height
      }
    )
    
    (map-set livestock-rights-registry
      { livestock-id: livestock-id, holder: tx-sender }
      { rights-count: (+ u1 (default-to u0 (get rights-count (map-get? livestock-rights-registry { livestock-id: livestock-id, holder: tx-sender })))) }
    )
    
    (var-set next-rights-id (+ rights-id u1))
    (ok rights-id)
  )
)

(define-public (list-breeding-rights (rights-id uint) (price uint) (duration uint))
  (let
    (
      (rights-data (unwrap! (map-get? breeding-rights { rights-id: rights-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender (get holder rights-data)) err-not-authorized)
    (asserts! (get active rights-data) err-rights-sold)
    (asserts! (> price u0) err-invalid-amount)
    
    (map-set rights-listings
      { rights-id: rights-id }
      {
        seller: tx-sender,
        price: price,
        expiry: (+ stacks-block-height duration),
        active: true
      }
    )
    (ok true)
  )
)

(define-public (purchase-breeding-rights (rights-id uint))
  (let
    (
      (rights-data (unwrap! (map-get? breeding-rights { rights-id: rights-id }) err-not-found))
      (listing (unwrap! (map-get? rights-listings { rights-id: rights-id }) err-not-for-sale))
      (seller (get seller listing))
    )
    (asserts! (get active listing) err-not-for-sale)
    (asserts! (< stacks-block-height (get expiry listing)) err-listing-expired)
    
    (try! (stx-transfer? (get price listing) tx-sender seller))
    
    (map-set breeding-rights
      { rights-id: rights-id }
      (merge rights-data { holder: tx-sender })
    )
    
    (map-set rights-listings
      { rights-id: rights-id }
      (merge listing { active: false })
    )
    
    (map-set livestock-rights-registry
      { livestock-id: (get livestock-id rights-data), holder: tx-sender }
      { rights-count: (+ u1 (default-to u0 (get rights-count (map-get? livestock-rights-registry { livestock-id: (get livestock-id rights-data), holder: tx-sender })))) }
    )
    
    (ok true)
  )
)

(define-public (exercise-breeding-right (rights-id uint))
  (let
    (
      (rights-data (unwrap! (map-get? breeding-rights { rights-id: rights-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender (get holder rights-data)) err-not-authorized)
    (asserts! (get active rights-data) err-rights-sold)
    (asserts! (< (get cycles-used rights-data) (get breeding-cycles rights-data)) err-invalid-amount)
    
    (map-set breeding-rights
      { rights-id: rights-id }
      (merge rights-data { 
        cycles-used: (+ (get cycles-used rights-data) u1),
        active: (< (+ (get cycles-used rights-data) u1) (get breeding-cycles rights-data))
      })
    )
    (ok (get offspring-share-percent rights-data))
  )
)

(define-read-only (get-breeding-rights (rights-id uint))
  (map-get? breeding-rights { rights-id: rights-id })
)

(define-read-only (get-rights-listing (rights-id uint))
  (map-get? rights-listings { rights-id: rights-id })
)

(define-read-only (get-holder-rights-count (livestock-id uint) (holder principal))
  (default-to { rights-count: u0 } (map-get? livestock-rights-registry { livestock-id: livestock-id, holder: holder }))
)

(define-read-only (calculate-breeding-value (rights-id uint) (market-multiplier uint))
  (let
    (
      (rights-data (unwrap! (map-get? breeding-rights { rights-id: rights-id }) err-not-found))
      (remaining-cycles (- (get breeding-cycles rights-data) (get cycles-used rights-data)))
    )
    (ok (/ (* (* remaining-cycles (get offspring-share-percent rights-data)) market-multiplier) u100))
  )
)
