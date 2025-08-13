(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u300))
(define-constant err-not-found (err u301))
(define-constant err-invalid-data (err u302))
(define-constant err-vet-not-registered (err u303))

(define-data-var next-record-id uint u1)

(define-map registered-vets
  { vet: principal }
  { name: (string-ascii 50), license: (string-ascii 30), active: bool }
)

(define-map health-records
  { record-id: uint }
  {
    livestock-id: uint,
    vet: principal,
    health-score: uint,
    vaccination-status: bool,
    last-checkup: uint,
    notes: (string-ascii 200),
    verified: bool,
    created-at: uint
  }
)

(define-map livestock-health-summary
  { livestock-id: uint }
  {
    current-health-score: uint,
    last-checkup: uint,
    vaccination-current: bool,
    total-records: uint,
    average-health-score: uint
  }
)

(define-public (register-veterinarian (vet principal) (name (string-ascii 50)) (license (string-ascii 30)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (map-set registered-vets
      { vet: vet }
      { name: name, license: license, active: true }
    )
    (ok true)
  )
)

(define-public (submit-health-record (livestock-id uint) (health-score uint) (vaccination-status bool) (notes (string-ascii 200)))
  (let
    (
      (record-id (var-get next-record-id))
      (vet-data (unwrap! (map-get? registered-vets { vet: tx-sender }) err-vet-not-registered))
      (current-summary (default-to 
        { current-health-score: u0, last-checkup: u0, vaccination-current: false, total-records: u0, average-health-score: u0 }
        (map-get? livestock-health-summary { livestock-id: livestock-id })))
      (new-total (+ (get total-records current-summary) u1))
      (new-average (/ (+ (* (get average-health-score current-summary) (get total-records current-summary)) health-score) new-total))
    )
    (asserts! (get active vet-data) err-vet-not-registered)
    (asserts! (and (>= health-score u1) (<= health-score u10)) err-invalid-data)
    
    (map-set health-records
      { record-id: record-id }
      {
        livestock-id: livestock-id,
        vet: tx-sender,
        health-score: health-score,
        vaccination-status: vaccination-status,
        last-checkup: stacks-block-height,
        notes: notes,
        verified: true,
        created-at: stacks-block-height
      }
    )
    
    (map-set livestock-health-summary
      { livestock-id: livestock-id }
      {
        current-health-score: health-score,
        last-checkup: stacks-block-height,
        vaccination-current: vaccination-status,
        total-records: new-total,
        average-health-score: new-average
      }
    )
    
    (var-set next-record-id (+ record-id u1))
    (ok record-id)
  )
)

(define-read-only (get-health-summary (livestock-id uint))
  (map-get? livestock-health-summary { livestock-id: livestock-id })
)

(define-read-only (get-health-record (record-id uint))
  (map-get? health-records { record-id: record-id })
)

(define-read-only (get-veterinarian (vet principal))
  (map-get? registered-vets { vet: vet })
)

(define-read-only (calculate-health-risk-factor (livestock-id uint))
  (let
    (
      (health-data (unwrap! (map-get? livestock-health-summary { livestock-id: livestock-id }) err-not-found))
      (health-score (get current-health-score health-data))
      (vaccination-current (get vaccination-current health-data))
      (checkup-age (- stacks-block-height (get last-checkup health-data)))
    )
    (ok (if (and (>= health-score u8) vaccination-current (< checkup-age u1008))
          u1
          (if (and (>= health-score u6) (< checkup-age u2016))
            u2
            u3)))
  )
)
