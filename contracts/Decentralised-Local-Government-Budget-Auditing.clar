(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-budget-locked (err u106))
(define-constant err-invalid-status (err u107))

(define-data-var next-budget-id uint u1)
(define-data-var next-audit-id uint u1)

(define-map budgets
    uint
    {
        government-id: principal,
        title: (string-ascii 100),
        total-amount: uint,
        allocated-amount: uint,
        status: (string-ascii 20),
        created-at: uint,
        deadline: uint,
    }
)

(define-map budget-items
    {
        budget-id: uint,
        item-id: uint,
    }
    {
        description: (string-ascii 200),
        allocated-amount: uint,
        spent-amount: uint,
        category: (string-ascii 50),
    }
)

(define-map audits
    uint
    {
        budget-id: uint,
        auditor: principal,
        findings: (string-ascii 500),
        recommendation: (string-ascii 300),
        score: uint,
        status: (string-ascii 20),
        created-at: uint,
    }
)

(define-map government-entities
    principal
    {
        name: (string-ascii 100),
        jurisdiction: (string-ascii 100),
        registered-at: uint,
        active: bool,
    }
)

(define-map authorized-auditors
    principal
    {
        name: (string-ascii 100),
        certification: (string-ascii 100),
        reputation-score: uint,
        active: bool,
    }
)

(define-map expenditures
    {
        budget-id: uint,
        expenditure-id: uint,
    }
    {
        item-id: uint,
        amount: uint,
        recipient: principal,
        description: (string-ascii 200),
        timestamp: uint,
        verified: bool,
    }
)

(define-public (register-government
        (name (string-ascii 100))
        (jurisdiction (string-ascii 100))
    )
    (begin
        (asserts! (is-none (map-get? government-entities tx-sender))
            err-already-exists
        )
        (ok (map-set government-entities tx-sender {
            name: name,
            jurisdiction: jurisdiction,
            registered-at: stacks-block-height,
            active: true,
        }))
    )
)

(define-public (register-auditor
        (name (string-ascii 100))
        (certification (string-ascii 100))
    )
    (begin
        (asserts! (is-none (map-get? authorized-auditors tx-sender))
            err-already-exists
        )
        (ok (map-set authorized-auditors tx-sender {
            name: name,
            certification: certification,
            reputation-score: u0,
            active: true,
        }))
    )
)

(define-public (create-budget
        (title (string-ascii 100))
        (total-amount uint)
        (deadline uint)
    )
    (let (
            (budget-id (var-get next-budget-id))
            (government (unwrap! (map-get? government-entities tx-sender) err-unauthorized))
        )
        (asserts! (> total-amount u0) err-invalid-amount)
        (asserts! (> deadline stacks-block-height) err-invalid-amount)
        (asserts! (get active government) err-unauthorized)
        (map-set budgets budget-id {
            government-id: tx-sender,
            title: title,
            total-amount: total-amount,
            allocated-amount: u0,
            status: "draft",
            created-at: stacks-block-height,
            deadline: deadline,
        })
        (var-set next-budget-id (+ budget-id u1))
        (ok budget-id)
    )
)

(define-public (add-budget-item
        (budget-id uint)
        (item-id uint)
        (description (string-ascii 200))
        (allocated-amount uint)
        (category (string-ascii 50))
    )
    (let ((budget (unwrap! (map-get? budgets budget-id) err-not-found)))
        (asserts! (is-eq (get government-id budget) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status budget) "draft") err-budget-locked)
        (asserts! (> allocated-amount u0) err-invalid-amount)
        (ok (map-set budget-items {
            budget-id: budget-id,
            item-id: item-id,
        } {
            description: description,
            allocated-amount: allocated-amount,
            spent-amount: u0,
            category: category,
        }))
    )
)

(define-public (finalize-budget (budget-id uint))
    (let ((budget (unwrap! (map-get? budgets budget-id) err-not-found)))
        (asserts! (is-eq (get government-id budget) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status budget) "draft") err-budget-locked)
        (ok (map-set budgets budget-id (merge budget { status: "active" })))
    )
)

(define-public (record-expenditure
        (budget-id uint)
        (expenditure-id uint)
        (item-id uint)
        (amount uint)
        (recipient principal)
        (description (string-ascii 200))
    )
    (let (
            (budget (unwrap! (map-get? budgets budget-id) err-not-found))
            (budget-item (unwrap!
                (map-get? budget-items {
                    budget-id: budget-id,
                    item-id: item-id,
                })
                err-not-found
            ))
        )
        (asserts! (is-eq (get government-id budget) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status budget) "active") err-invalid-status)
        (asserts!
            (>= (get allocated-amount budget-item)
                (+ (get spent-amount budget-item) amount)
            )
            err-insufficient-funds
        )
        (asserts! (> amount u0) err-invalid-amount)
        (map-set expenditures {
            budget-id: budget-id,
            expenditure-id: expenditure-id,
        } {
            item-id: item-id,
            amount: amount,
            recipient: recipient,
            description: description,
            timestamp: stacks-block-height,
            verified: false,
        })
        (ok (map-set budget-items {
            budget-id: budget-id,
            item-id: item-id,
        }
            (merge budget-item { spent-amount: (+ (get spent-amount budget-item) amount) })
        ))
    )
)

(define-public (submit-audit
        (budget-id uint)
        (findings (string-ascii 500))
        (recommendation (string-ascii 300))
        (score uint)
    )
    (let (
            (audit-id (var-get next-audit-id))
            (budget (unwrap! (map-get? budgets budget-id) err-not-found))
            (auditor (unwrap! (map-get? authorized-auditors tx-sender) err-unauthorized))
        )
        (asserts! (get active auditor) err-unauthorized)
        (asserts! (<= score u100) err-invalid-amount)
        (map-set audits audit-id {
            budget-id: budget-id,
            auditor: tx-sender,
            findings: findings,
            recommendation: recommendation,
            score: score,
            status: "submitted",
            created-at: stacks-block-height,
        })
        (var-set next-audit-id (+ audit-id u1))
        (ok audit-id)
    )
)

(define-public (verify-expenditure
        (budget-id uint)
        (expenditure-id uint)
    )
    (let (
            (expenditure (unwrap!
                (map-get? expenditures {
                    budget-id: budget-id,
                    expenditure-id: expenditure-id,
                })
                err-not-found
            ))
            (auditor (unwrap! (map-get? authorized-auditors tx-sender) err-unauthorized))
        )
        (asserts! (get active auditor) err-unauthorized)
        (ok (map-set expenditures {
            budget-id: budget-id,
            expenditure-id: expenditure-id,
        }
            (merge expenditure { verified: true })
        ))
    )
)

(define-public (approve-audit (audit-id uint))
    (let ((audit (unwrap! (map-get? audits audit-id) err-not-found)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-eq (get status audit) "submitted") err-invalid-status)
        (ok (map-set audits audit-id (merge audit { status: "approved" })))
    )
)

(define-public (update-auditor-reputation
        (auditor principal)
        (new-score uint)
    )
    (let ((auditor-data (unwrap! (map-get? authorized-auditors auditor) err-not-found)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-score u100) err-invalid-amount)
        (ok (map-set authorized-auditors auditor
            (merge auditor-data { reputation-score: new-score })
        ))
    )
)

(define-read-only (get-budget (budget-id uint))
    (map-get? budgets budget-id)
)

(define-read-only (get-budget-item
        (budget-id uint)
        (item-id uint)
    )
    (map-get? budget-items {
        budget-id: budget-id,
        item-id: item-id,
    })
)

(define-read-only (get-audit (audit-id uint))
    (map-get? audits audit-id)
)

(define-read-only (get-government-entity (government principal))
    (map-get? government-entities government)
)

(define-read-only (get-auditor (auditor principal))
    (map-get? authorized-auditors auditor)
)

(define-read-only (get-expenditure
        (budget-id uint)
        (expenditure-id uint)
    )
    (map-get? expenditures {
        budget-id: budget-id,
        expenditure-id: expenditure-id,
    })
)

(define-read-only (get-next-budget-id)
    (var-get next-budget-id)
)

(define-read-only (get-next-audit-id)
    (var-get next-audit-id)
)

(define-read-only (get-contract-owner)
    contract-owner
)

(define-constant err-already-paid (err u108))
(define-constant err-not-verified (err u109))

(define-map budget-balances uint uint)
(define-map paid-expenditures { budget-id: uint, expenditure-id: uint } bool)

(define-read-only (get-budget-balance (budget-id uint))
    (default-to u0 (map-get? budget-balances budget-id))
)

(define-read-only (is-expenditure-paid (budget-id uint) (expenditure-id uint))
    (map-get? paid-expenditures { budget-id: budget-id, expenditure-id: expenditure-id })
)

(define-public (deposit-budget-funds (budget-id uint) (amount uint))
    (let (
            (budget (unwrap! (map-get? budgets budget-id) err-not-found))
            (recipient (as-contract tx-sender))
        )
        (asserts! (is-eq (get government-id budget) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status budget) "active") err-invalid-status)
        (asserts! (> amount u0) err-invalid-amount)
        (unwrap! (stx-transfer? amount tx-sender recipient) err-insufficient-funds)
        (let ((current (default-to u0 (map-get? budget-balances budget-id))))
            (ok (map-set budget-balances budget-id (+ current amount)))
        )
    )
)

(define-public (withdraw-budget-funds (budget-id uint) (amount uint) (recipient principal))
    (let (
            (budget (unwrap! (map-get? budgets budget-id) err-not-found))
            (sender (as-contract tx-sender))
            (current (default-to u0 (map-get? budget-balances budget-id)))
        )
        (asserts! (is-eq (get government-id budget) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status budget) "active") err-invalid-status)
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (<= amount current) err-insufficient-funds)
        (unwrap! (stx-transfer? amount sender recipient) err-insufficient-funds)
        (ok (map-set budget-balances budget-id (- current amount)))
    )
)

(define-public (disburse-verified-expenditure (budget-id uint) (expenditure-id uint))
    (let (
            (budget (unwrap! (map-get? budgets budget-id) err-not-found))
            (expenditure (unwrap! (map-get? expenditures { budget-id: budget-id, expenditure-id: expenditure-id }) err-not-found))
            (paid (default-to false (map-get? paid-expenditures { budget-id: budget-id, expenditure-id: expenditure-id })))
            (sender (as-contract tx-sender))
            (current (default-to u0 (map-get? budget-balances budget-id)))
        )
        (asserts! (is-eq (get government-id budget) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status budget) "active") err-invalid-status)
        (asserts! (is-eq paid false) err-already-paid)
        (asserts! (is-eq (get verified expenditure) true) err-not-verified)
        (asserts! (<= (get amount expenditure) current) err-insufficient-funds)
        (unwrap! (stx-transfer? (get amount expenditure) sender (get recipient expenditure)) err-insufficient-funds)
        (map-set paid-expenditures { budget-id: budget-id, expenditure-id: expenditure-id } true)
        (ok (map-set budget-balances budget-id (- current (get amount expenditure))))
    )
)
