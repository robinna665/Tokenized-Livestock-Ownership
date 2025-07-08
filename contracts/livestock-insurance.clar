(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-invalid-amount (err u202))
(define-constant err-already-insured (err u203))
(define-constant err-claim-exists (err u204))
(define-constant err-voting-ended (err u205))
(define-constant err-not-shareholder (err u206))

(define-data-var next-policy-id uint u1)
(define-data-var next-claim-id uint u1)
(define-data-var insurance-pool uint u0)

(define-map insurance-policies
  { policy-id: uint }
  {
    livestock-id: uint,
    owner: principal,
    coverage-amount: uint,
    premium-paid: uint,
    active: bool,
    created-at: uint
  }
)

(define-map livestock-policy-lookup
  { livestock-id: uint }
  { policy-id: uint }
)

(define-map insurance-claims
  { claim-id: uint }
  {
    policy-id: uint,
    livestock-id: uint,
    claimant: principal,
    claim-amount: uint,
    description: (string-ascii 200),
    votes-for: uint,
    votes-against: uint,
    voting-deadline: uint,
    processed: bool,
    approved: bool,
    created-at: uint
  }
)

(define-map claim-votes
  { claim-id: uint, voter: principal }
  { vote: bool, voted-at: uint }
)

(define-public (purchase-insurance (livestock-id uint) (coverage-amount uint))
  (let
    (
      (policy-id (var-get next-policy-id))
      (premium (/ coverage-amount u20))
      (existing-policy (map-get? livestock-policy-lookup { livestock-id: livestock-id }))
    )
    (asserts! (is-none existing-policy) err-already-insured)
    (asserts! (> coverage-amount u0) err-invalid-amount)
    
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    
    (map-set insurance-policies
      { policy-id: policy-id }
      {
        livestock-id: livestock-id,
        owner: tx-sender,
        coverage-amount: coverage-amount,
        premium-paid: premium,
        active: true,
        created-at: stacks-block-height
      }
    )
    
    (map-set livestock-policy-lookup
      { livestock-id: livestock-id }
      { policy-id: policy-id }
    )
    
    (var-set insurance-pool (+ (var-get insurance-pool) premium))
    (var-set next-policy-id (+ policy-id u1))
    (ok policy-id)
  )
)

(define-public (submit-claim (livestock-id uint) (claim-amount uint) (description (string-ascii 200)))
  (let
    (
      (policy-lookup (unwrap! (map-get? livestock-policy-lookup { livestock-id: livestock-id }) err-not-found))
      (policy-data (unwrap! (map-get? insurance-policies { policy-id: (get policy-id policy-lookup) }) err-not-found))
      (claim-id (var-get next-claim-id))
    )
    (asserts! (is-eq tx-sender (get owner policy-data)) err-not-found)
    (asserts! (get active policy-data) err-not-found)
    (asserts! (<= claim-amount (get coverage-amount policy-data)) err-invalid-amount)
    
    (map-set insurance-claims
      { claim-id: claim-id }
      {
        policy-id: (get policy-id policy-lookup),
        livestock-id: livestock-id,
        claimant: tx-sender,
        claim-amount: claim-amount,
        description: description,
        votes-for: u0,
        votes-against: u0,
        voting-deadline: (+ stacks-block-height u144),
        processed: false,
        approved: false,
        created-at: stacks-block-height
      }
    )
    
    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)

(define-public (vote-on-claim (claim-id uint) (approve bool))
  (let
    (
      (claim-data (unwrap! (map-get? insurance-claims { claim-id: claim-id }) err-not-found))
      (existing-vote (map-get? claim-votes { claim-id: claim-id, voter: tx-sender }))
    )
    (asserts! (is-none existing-vote) err-claim-exists)
    (asserts! (< stacks-block-height (get voting-deadline claim-data)) err-voting-ended)
    (asserts! (not (get processed claim-data)) err-voting-ended)
    
    (map-set claim-votes
      { claim-id: claim-id, voter: tx-sender }
      { vote: approve, voted-at: stacks-block-height }
    )
    
    (map-set insurance-claims
      { claim-id: claim-id }
      (merge claim-data {
        votes-for: (if approve (+ (get votes-for claim-data) u1) (get votes-for claim-data)),
        votes-against: (if approve (get votes-against claim-data) (+ (get votes-against claim-data) u1))
      })
    )
    
    (ok true)
  )
)

(define-public (process-claim (claim-id uint))
  (let
    (
      (claim-data (unwrap! (map-get? insurance-claims { claim-id: claim-id }) err-not-found))
      (total-votes (+ (get votes-for claim-data) (get votes-against claim-data)))
      (approval-threshold (/ total-votes u2))
      (claim-approved (> (get votes-for claim-data) approval-threshold))
    )
    (asserts! (>= stacks-block-height (get voting-deadline claim-data)) err-voting-ended)
    (asserts! (not (get processed claim-data)) err-voting-ended)
    (asserts! (> total-votes u0) err-not-found)
    
    (map-set insurance-claims
      { claim-id: claim-id }
      (merge claim-data { processed: true, approved: claim-approved })
    )
    
    (if claim-approved
      (begin
        (try! (as-contract (stx-transfer? (get claim-amount claim-data) tx-sender (get claimant claim-data))))
        (var-set insurance-pool (- (var-get insurance-pool) (get claim-amount claim-data)))
        (ok true)
      )
      (ok false)
    )
  )
)

(define-read-only (get-policy (policy-id uint))
  (map-get? insurance-policies { policy-id: policy-id })
)

(define-read-only (get-livestock-policy (livestock-id uint))
  (match (map-get? livestock-policy-lookup { livestock-id: livestock-id })
    policy-lookup (map-get? insurance-policies { policy-id: (get policy-id policy-lookup) })
    none
  )
)

(define-read-only (get-claim (claim-id uint))
  (map-get? insurance-claims { claim-id: claim-id })
)

(define-read-only (get-insurance-pool-balance)
  (var-get insurance-pool)
)
