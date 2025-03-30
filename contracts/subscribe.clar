;; STXSubscriptor - Subscription Management Smart Contract
;; Handles subscription payments and management through STX locking

;; Constants and Variables
(define-data-var admin principal tx-sender)
(define-data-var min-subscription-days uint u30)
(define-data-var cancellation-penalty-rate uint u100)
(define-data-var referral-reward-rate uint u500) ;; 5% reward in basis points

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
        is-valid: bool,
        tier-id: uint,  ;; New field for subscription tier
        referrer: (optional principal) ;; New field for tracking referrals
    }
)

;; New map for tiered pricing plans
(define-map tier-pricing
    { vendor-id: principal, tier-id: uint }
    {
        name: (string-ascii 50),
        base-price: uint,
        description: (string-ascii 200),
        is-active: bool
    }
)

;; New map for tracking referral rewards
(define-map referral-rewards
    { referrer: principal }
    { total-earned: uint }
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

;; New function for vendors to create subscription tiers
(define-public (create-subscription-tier (tier-id uint) (name (string-ascii 50)) (price uint) (description (string-ascii 200)))
    (begin
        (asserts! (is-approved-vendor tx-sender) (err u15))
        (asserts! (> price u0) (err u5))
        (asserts! (not (is-tier-active tx-sender tier-id)) (err u20))
        (ok (map-set tier-pricing 
            { vendor-id: tx-sender, tier-id: tier-id }
            {
                name: name,
                base-price: price,
                description: description,
                is-active: true
            }
        ))
    )
)

;; New function to check if a tier exists and is active
(define-read-only (is-tier-active (vendor principal) (tier-id uint))
    (match (map-get? tier-pricing { vendor-id: vendor, tier-id: tier-id })
        tier-data (get is-active tier-data)
        false
    )
)

(define-public (collect-payment (customer principal))
    (let
        (
            (plan-data (unwrap! (map-get? subscription-plans {customer: customer}) (err u1)))
            (current-block (unwrap-panic (get-block-info? time u0)))
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
            (current-block (unwrap-panic (get-block-info? time u0)))
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

(define-read-only (get-tier-details (vendor principal) (tier-id uint))
    (map-get? tier-pricing {vendor-id: vendor, tier-id: tier-id})
)

(define-read-only (get-minimum-subscription-period)
    (var-get min-subscription-days)
)

(define-read-only (get-admin)
    (var-get admin)
)

(define-read-only (get-referral-rewards (referrer principal))
    (default-to { total-earned: u0 } (map-get? referral-rewards {referrer: referrer}))
)

;; Admin Functions
(define-public (update-minimum-period (new-period uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err u403))
        (asserts! (> new-period u0) (err u9))
        (ok (var-set min-subscription-days new-period))
    )
)

(define-public (update-referral-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err u403))
        (asserts! (<= new-rate u10000) (err u24)) ;; Can't exceed 100%
        (ok (var-set referral-reward-rate new-rate))
    )
)

(define-public (transfer-admin-rights (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) (err u403))
        (asserts! (not (is-eq new-admin tx-sender)) (err u10))
        (ok (var-set admin new-admin))
    )
)