;; Community Garden Plot Management Smart Contract

;; Constants
(define-constant GARDEN-ADMIN tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SEASON-CLOSED (err u101))
(define-constant ERR-SEASON-ACTIVE (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-INVALID-PARAMETER (err u106))

;; Data Variables
(define-data-var growing-season-active bool false)
(define-data-var plot-reservation-fee uint u1000000) ;; 1 STX
(define-data-var season-end-block uint u0)
(define-data-var max-plots-per-gardener uint u5)

;; Maps
(define-map gardener-plots principal uint)
(define-map gardener-registry {position: uint} {gardener: principal})

;; Variables
(define-data-var gardener-count uint u0)
(define-data-var total-plots-reserved uint u0)

;; Private Functions
(define-private (is-admin)
  (is-eq tx-sender GARDEN-ADMIN)
)

(define-private (is-season-active)
  (var-get growing-season-active)
)

(define-private (register-gardener (gardener principal))
  (let (
    (current-count (var-get gardener-count))
    (new-count (+ current-count u1))
  )
    (map-insert gardener-registry {position: new-count} {gardener: gardener})
    (var-set gardener-count new-count)
  )
)

;; Public Functions
(define-public (start-growing-season (duration uint) (fee uint) (max-plots uint))
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-season-active)) ERR-SEASON-ACTIVE)
    (asserts! (> duration u0) ERR-INVALID-PARAMETER)
    (asserts! (> fee u0) ERR-INVALID-PARAMETER)
    (asserts! (> max-plots u0) ERR-INVALID-PARAMETER)
    (var-set growing-season-active true)
    (var-set plot-reservation-fee fee)
    (var-set season-end-block (+ block-height duration))
    (var-set max-plots-per-gardener max-plots)
    (var-set gardener-count u0)
    (var-set total-plots-reserved u0)
    (ok true)
  )
)

(define-public (reserve-plots (quantity uint))
  (let (
    (gardener tx-sender)
    (fee (var-get plot-reservation-fee))
    (total-fee (* fee quantity))
    (current-plot-count (default-to u0 (map-get? gardener-plots gardener)))
    (new-plot-count (+ current-plot-count quantity))
  )
    (asserts! (is-season-active) ERR-SEASON-CLOSED)
    (asserts! (<= block-height (var-get season-end-block)) ERR-SEASON-CLOSED)
    (asserts! (>= (stx-get-balance gardener) total-fee) ERR-INSUFFICIENT-FUNDS)
    (asserts! (<= new-plot-count (var-get max-plots-per-gardener)) ERR-INVALID-PARAMETER)
    (try! (stx-transfer? total-fee gardener (as-contract tx-sender)))
    (map-set gardener-plots gardener new-plot-count)
    (match (map-get? gardener-plots gardener)
      prev-count (register-gardener gardener)
      (register-gardener gardener)
    )
    (var-set total-plots-reserved (+ (var-get total-plots-reserved) quantity))
    (ok new-plot-count)
  )
)

(define-public (end-growing-season)
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (is-season-active) ERR-SEASON-CLOSED)
    (asserts! (>= block-height (var-get season-end-block)) ERR-SEASON-CLOSED)
    (var-set growing-season-active false)
    (ok true)
  )
)

(define-read-only (get-plot-fee)
  (ok (var-get plot-reservation-fee))
)

(define-read-only (get-garden-status)
  (ok {
    active: (var-get growing-season-active),
    end-block: (var-get season-end-block),
    current-block: block-height,
    total-plots: (var-get total-plots-reserved),
    gardener-count: (var-get gardener-count),
    max-plots-per-gardener: (var-get max-plots-per-gardener)
  })
)

(define-read-only (get-gardener-plots (gardener principal))
  (ok (default-to u0 (map-get? gardener-plots gardener)))
)

(define-public (refund-gardener-fees)
  (let (
    (gardener tx-sender)
    (plot-count (default-to u0 (map-get? gardener-plots gardener)))
    (refund-amount (* plot-count (var-get plot-reservation-fee)))
  )
    (asserts! (not (is-season-active)) ERR-SEASON-ACTIVE)
    (asserts! (> plot-count u0) ERR-INVALID-PARAMETER)
    (try! (as-contract (stx-transfer? refund-amount tx-sender gardener)))
    (map-delete gardener-plots gardener)
    (var-set total-plots-reserved (- (var-get total-plots-reserved) plot-count))
    (ok refund-amount)
  )
)