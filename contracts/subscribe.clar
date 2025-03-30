;; STXSubscriptor - Subscription Management Smart Contract
;; Handles subscription payments and management through STX locking

;; Constants and Variables
(define-data-var admin principal tx-sender)
(define-data-var min-subscription-days uint u30)
(define-data-var cancellation-penalty-rate uint u100)

;; Data Maps
(define-map vendors
    { vendor-id: principal }
    { is-active: bool }
)

(define-map subscription-plans
    { customer: principal }
    {
        vendor: principal,
        fee-amount: uint,
        activation-block: uint,
        expiration-block: uint,
        billing-cycle: uint,
        last-billing-block: uint,
        is-valid: bool
    }
)

;; Authorization Functions
(define-read-only (is-approved-vendor (vendor principal))
    (default-to false (get is-active (map-get? vendors { vendor-id: vendor })))
)

(define-public (add-vendor (vendor principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err u403))
        (asserts! (not (is-approved-vendor vendor)) (err u13))
        (ok (map-set vendors { vendor-id: vendor } { is-active: true }))
    )
)

(define-public (deactivate-vendor (vendor principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err u403))
        (asserts! (is-approved-vendor vendor) (err u14))
        (ok (map-set vendors { vendor-id: vendor } { is-active: false }))
    )
)

;; Public Functions
(define-public (subscribe (vendor principal) (fee-amount uint) (duration uint) (cycle uint))
    (let
        (
            (current-block (unwrap-panic (get-stacks-block-info? time u0)))
            (total-fee (* fee-amount (/ duration cycle)))
        )
        (asserts! (is-approved-vendor vendor) (err u15))
        (asserts! (> fee-amount u0) (err u5))
        (asserts! (> duration u0) (err u6))
        (asserts! (> cycle u0) (err u7))
        (asserts! (>= duration cycle) (err u8))
        (asserts! (not (is-eq vendor tx-sender)) (err u11))
        (try! (stx-transfer? total-fee tx-sender (as-contract tx-sender)))
        (ok (map-set subscription-plans
            { customer: tx-sender }
            {
                vendor: vendor,
                fee-amount: fee-amount,
                activation-block: current-block,
                expiration-block: (+ current-block duration),
                billing-cycle: cycle,
                last-billing-block: current-block,
                is-valid: true
            }
        ))
    )
)

(define-public (collect-payment (customer principal))
    (let
        (
            (plan-data (unwrap! (map-get? subscription-plans {customer: customer}) (err u1)))
            (current-block (unwrap-panic (get-stacks-block-info? time u0)))
            (subscription-id { customer: customer })
        )
        ;; Validate subscription exists and get data
        (asserts! (is-some (map-get? subscription-plans subscription-id)) (err u18))
        (asserts! (is-eq tx-sender (get vendor plan-data)) (err u16))
        (asserts! (is-approved-vendor tx-sender) (err u17))
        (asserts! (get is-valid plan-data) (err u2))
        (asserts! (>= current-block (+ (get last-billing-block plan-data) (get billing-cycle plan-data))) (err u3))
        (asserts! (<= current-block (get expiration-block plan-data)) (err u4))
        
        (try! (as-contract
            (stx-transfer? (get fee-amount plan-data) tx-sender (get vendor plan-data))))
        
        (ok (map-set subscription-plans
            subscription-id
            (merge plan-data { last-billing-block: current-block })))
    )
)

(define-public (cancel-subscription)
    (let
        (
            (plan (unwrap! (map-get? subscription-plans {customer: tx-sender}) (err u1)))
            (current-block (unwrap-panic (get-stacks-block-info? time u0)))
            (blocks-remaining (- (get expiration-block plan) current-block))
            (min-blocks (* (var-get min-subscription-days) u144))
        )
        (asserts! (get is-valid plan) (err u2))
        
        (if (< blocks-remaining min-blocks)
            (let
                (
                    (fee (/ (* (get fee-amount plan) (var-get cancellation-penalty-rate)) u10000))
                )
                (try! (stx-transfer? fee tx-sender (get vendor plan)))
            )
            true
        )
        
        (ok (map-set subscription-plans
            { customer: tx-sender }
            (merge plan { is-valid: false })))
    )
)

;; Read-only Functions
(define-read-only (get-plan-details (customer principal))
    (map-get? subscription-plans {customer: customer})
)

(define-read-only (get-minimum-subscription-period)
    (var-get min-subscription-days)
)

(define-read-only (get-admin)
    (var-get admin)
)

;; Admin Functions
(define-public (update-minimum-period (new-period uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err u403))
        (asserts! (> new-period u0) (err u9))
        (ok (var-set min-subscription-days new-period))
    )
)

(define-public (transfer-admin-rights (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err u403))
        (asserts! (not (is-eq new-admin tx-sender)) (err u10))
        (ok (var-set admin new-admin))
    )
)