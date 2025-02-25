;; Community Garden Plot Management Smart Contract
;; Complete implementation with community fund and enhanced features

;; Constants
(define-constant GARDEN-ADMIN tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SEASON-CLOSED (err u101))
(define-constant ERR-SEASON-ACTIVE (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-NO-GARDENERS (err u104))
(define-constant ERR-SEASON-ENDED (err u105))
(define-constant ERR-INVALID-PARAMETER (err u106))
(define-constant ERR-NOT-SELECTED (err u107))
(define-constant ERR-ALREADY-DISTRIBUTED (err u108))

;; Data Variables
(define-data-var growing-season-active bool false)
(define-data-var plot-reservation-fee uint u1000000) ;; 1 STX
(define-data-var season-end-block uint u0)
(define-data-var featured-gardener (optional principal) none)
(define-data-var harvest-share-distributed bool false)
(define-data-var minimum-gardeners uint u5)
(define-data-var max-plots-per-gardener uint u10)
(define-data-var community-fund-rate uint u5) ;; 5% contribution to community fund
(define-data-var seasonal-name (string-ascii 30) "")

;; Maps
(define-map gardener-plots principal uint)
(define-map gardener-registry {position: uint} {gardener: principal})
(define-map gardener-positions principal uint)
(define-map plot-usage {season: (string-ascii 30), gardener: principal} {crop-type: (string-ascii 20), organic: bool})

;; Variables
(define-data-var gardener-count uint u0)
(define-data-var total-plots-reserved uint u0)
(define-data-var season-count uint u0)

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
    (map-insert gardener-positions gardener new-count)
    (var-set gardener-count new-count)
  )
)

(define-private (select-random-gardener (seed uint))
  (let (
    (combined-value (+ (var-get gardener-count) seed block-height))
    (random-value (mod combined-value (var-get gardener-count)))
  )
    (if (is-eq random-value u0)
      u1
      (+ random-value u1)
    )
  )
)

(define-private (calculate-community-contribution (amount uint))
  (/ (* amount (var-get community-fund-rate)) u100)
)

;; Public Functions
(define-public (start-growing-season (duration uint) (fee uint) (min-gardeners uint) (max-plots uint) (season-name (string-ascii 30)) (fund-rate uint))
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-season-active)) ERR-SEASON-ACTIVE)
    (asserts! (> duration u0) ERR-INVALID-PARAMETER)
    (asserts! (> fee u0) ERR-INVALID-PARAMETER)
    (asserts! (>= min-gardeners u2) ERR-INVALID-PARAMETER)
    (asserts! (> max-plots u0) ERR-INVALID-PARAMETER)
    (asserts! (< fund-rate u20) ERR-INVALID-PARAMETER)
    (var-set growing-season-active true)
    (var-set plot-reservation-fee fee)
    (var-set season-end-block (+ block-height duration))
    (var-set minimum-gardeners min-gardeners)
    (var-set max-plots-per-gardener max-plots)
    (var-set community-fund-rate fund-rate)
    (var-set harvest-share-distributed false)
    (var-set gardener-count u0)
    (var-set total-plots-reserved u0)
    (var-set seasonal-name season-name)
    (var-set season-count (+ (var-get season-count) u1))
    (ok true)
  )
)

(define-public (reserve-plots (quantity uint) (crop-type (string-ascii 20)) (organic bool))
  (let (
    (gardener tx-sender)
    (fee (var-get plot-reservation-fee))
    (total-fee (* fee quantity))
    (current-plot-count (default-to u0 (map-get? gardener-plots gardener)))
    (new-plot-count (+ current-plot-count quantity))
    (current-season (var-get seasonal-name))
  )
    (asserts! (is-season-active) ERR-SEASON-CLOSED)
    (asserts! (<= block-height (var-get season-end-block)) ERR-SEASON-ENDED)
    (asserts! (>= (stx-get-balance gardener) total-fee) ERR-INSUFFICIENT-FUNDS)
    (asserts! (<= new-plot-count (var-get max-plots-per-gardener)) ERR-INVALID-PARAMETER)
    (try! (stx-transfer? total-fee gardener (as-contract tx-sender)))
    (map-set gardener-plots gardener new-plot-count)
    (map-set plot-usage {season: current-season, gardener: gardener} {crop-type: crop-type, organic: organic})
    (match (map-get? gardener-positions gardener)
      position true
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
    (let (
      (total-gardeners (var-get gardener-count))
      (random-seed block-height)
    )
      (asserts! (>= total-gardeners (var-get minimum-gardeners)) ERR-NO-GARDENERS)
      (let (
        (selected-position (select-random-gardener random-seed))
        (selected-info (unwrap! (map-get? gardener-registry {position: selected-position}) ERR-NO-GARDENERS))
      )
        (var-set featured-gardener (some (get gardener selected-info)))
        (var-set growing-season-active false)
        (ok (get gardener selected-info))
      )
    )
  )
)

(define-public (claim-harvest-bonus)
  (let (
    (claimer tx-sender)
    (selected (unwrap! (var-get featured-gardener) ERR-NO-GARDENERS))
  )
    (asserts! (is-eq claimer selected) ERR-NOT-SELECTED)
    (asserts! (not (var-get harvest-share-distributed)) ERR-ALREADY-DISTRIBUTED)
    (let (
      (total-plot-fees (var-get total-plots-reserved))
      (community-contribution (calculate-community-contribution total-plot-fees))
      (gardener-bonus (- total-plot-fees community-contribution))
    )
      (try! (as-contract (stx-transfer? gardener-bonus tx-sender selected)))
      (var-set harvest-share-distributed true)
      (ok gardener-bonus)
    )
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
    minimum-gardeners: (var-get minimum-gardeners),
    max-plots-per-gardener: (var-get max-plots-per-gardener),
    season-name: (var-get seasonal-name),
    community-fund-rate: (var-get community-fund-rate),
    season-count: (var-get season-count)
  })
)

(define-read-only (get-gardener-plots (gardener principal))
  (ok (default-to u0 (map-get? gardener-plots gardener)))
)

(define-read-only (get-gardener-crop-info (gardener principal))
  (ok (map-get? plot-usage {season: (var-get seasonal-name), gardener: gardener}))
)

(define-read-only (get-featured-gardener)
  (ok (var-get featured-gardener))
)

(define-read-only (get-harvest-info)
  (ok {
    distributed: (var-get harvest-share-distributed),
    total-funds: (var-get total-plots-reserved),
    community-contribution: (calculate-community-contribution (var-get total-plots-reserved)),
    gardener-bonus: (- (var-get total-plots-reserved) (calculate-community-contribution (var-get total-plots-reserved)))
  })
)

(define-public (update-crop-info (crop-type (string-ascii 20)) (organic bool))
  (let (
    (gardener tx-sender)
    (current-season (var-get seasonal-name))
  )
    (asserts! (is-season-active) ERR-SEASON-CLOSED)
    (asserts! (> (default-to u0 (map-get? gardener-plots gardener)) u0) ERR-INVALID-PARAMETER)
    (map-set plot-usage {season: current-season, gardener: gardener} {crop-type: crop-type, organic: organic})
    (ok true)
  )
)

(define-public (collect-community-fund)
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-season-active)) ERR-SEASON-CLOSED)
    (asserts! (var-get harvest-share-distributed) ERR-ALREADY-DISTRIBUTED)
    (let (
      (total-fees (var-get total-plots-reserved))
      (contribution (calculate-community-contribution total-fees))
    )
      (try! (as-contract (stx-transfer? contribution tx-sender GARDEN-ADMIN)))
      (ok contribution)
    )
  )
)

(define-public (cancel-growing-season)
  (begin
    (asserts! (is-admin) ERR-NOT-AUTHORIZED)
    (asserts! (is-season-active) ERR-SEASON-CLOSED)
    (asserts! (< (var-get gardener-count) (var-get minimum-gardeners)) ERR-INVALID-PARAMETER)
    (var-set growing-season-active false)
    (ok true)
  )
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
    (map-delete gardener-positions gardener)
    (var-set total-plots-reserved (- (var-get total-plots-reserved) plot-count))
    (ok refund-amount)
  )
)