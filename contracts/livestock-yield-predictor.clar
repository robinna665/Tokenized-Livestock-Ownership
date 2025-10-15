(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u400))
(define-constant err-not-found (err u401))
(define-constant err-invalid-data (err u402))

(define-data-var market-volatility-factor uint u100)
(define-data-var seasonal-adjustment uint u110)

(define-map yield-history
  { livestock-id: uint, period: uint }
  { yield-amount: uint, market-price: uint, recorded-at: uint }
)

(define-map yield-predictions
  { livestock-id: uint }
  {
    predicted-yield: uint,
    confidence-score: uint,
    market-adjusted-value: uint,
    trend-direction: bool,
    last-calculated: uint
  }
)

(define-map performance-metrics
  { livestock-id: uint }
  {
    avg-monthly-yield: uint,
    yield-variance: uint,
    growth-rate: uint,
    seasonal-factor: uint,
    data-points: uint
  }
)

(define-public (record-yield-data (livestock-id uint) (yield-amount uint) (market-price uint))
  (let
    (
      (period (/ stacks-block-height u144))
      (current-metrics (default-to 
        { avg-monthly-yield: u0, yield-variance: u0, growth-rate: u100, seasonal-factor: u100, data-points: u0 }
        (map-get? performance-metrics { livestock-id: livestock-id })))
      (new-data-points (+ (get data-points current-metrics) u1))
      (new-avg (if (is-eq (get data-points current-metrics) u0)
                 yield-amount
                 (/ (+ (* (get avg-monthly-yield current-metrics) (get data-points current-metrics)) yield-amount) new-data-points)))
    )
    (asserts! (> yield-amount u0) err-invalid-data)
    (asserts! (> market-price u0) err-invalid-data)
    
    (map-set yield-history
      { livestock-id: livestock-id, period: period }
      { yield-amount: yield-amount, market-price: market-price, recorded-at: stacks-block-height }
    )
    
    (map-set performance-metrics
      { livestock-id: livestock-id }
      (merge current-metrics { 
        avg-monthly-yield: new-avg,
        data-points: new-data-points
      })
    )
    
    (ok true)
  )
)

(define-public (calculate-yield-prediction (livestock-id uint))
  (let
    (
      (metrics (unwrap! (map-get? performance-metrics { livestock-id: livestock-id }) err-not-found))
      (base-yield (get avg-monthly-yield metrics))
      (seasonal-factor (var-get seasonal-adjustment))
      (market-factor (var-get market-volatility-factor))
      (predicted-yield (/ (* (* base-yield seasonal-factor) market-factor) u10000))
      (confidence-score (if (> (get data-points metrics) u10) (* (get data-points metrics) u10) u100))
    )
    (asserts! (> base-yield u0) err-invalid-data)
    
    (map-set yield-predictions
      { livestock-id: livestock-id }
      {
        predicted-yield: predicted-yield,
        confidence-score: confidence-score,
        market-adjusted-value: (/ (* predicted-yield market-factor) u100),
        trend-direction: (> (get growth-rate metrics) u100),
        last-calculated: stacks-block-height
      }
    )
    
    (ok predicted-yield)
  )
)

(define-public (update-market-conditions (volatility uint) (seasonal uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (asserts! (and (>= volatility u50) (<= volatility u200)) err-invalid-data)
    (asserts! (and (>= seasonal u80) (<= seasonal u150)) err-invalid-data)
    
    (var-set market-volatility-factor volatility)
    (var-set seasonal-adjustment seasonal)
    (ok true)
  )
)

(define-read-only (get-yield-prediction (livestock-id uint))
  (map-get? yield-predictions { livestock-id: livestock-id })
)

(define-read-only (get-performance-metrics (livestock-id uint))
  (map-get? performance-metrics { livestock-id: livestock-id })
)

(define-read-only (get-dynamic-share-price (livestock-id uint) (base-price uint))
  (let
    (
      (prediction (map-get? yield-predictions { livestock-id: livestock-id }))
    )
    (match prediction
      pred-data (ok (/ (* base-price (get market-adjusted-value pred-data)) u100))
      (ok base-price)
    )
  )
)

(define-read-only (get-market-conditions)
  { volatility: (var-get market-volatility-factor), seasonal: (var-get seasonal-adjustment) }
)
