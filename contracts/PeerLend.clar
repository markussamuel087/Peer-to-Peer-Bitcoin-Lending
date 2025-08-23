(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-collateral (err u103))
(define-constant err-loan-active (err u104))
(define-constant err-loan-expired (err u105))
(define-constant err-invalid-amount (err u106))
(define-constant err-already-repaid (err u107))
(define-constant err-insufficient-balance (err u108))

(define-data-var next-loan-id uint u1)
(define-data-var platform-fee-rate uint u250)
(define-data-var min-collateral-ratio uint u150)

(define-map loans
  { loan-id: uint }
  {
    borrower: principal,
    lender: (optional principal),
    amount: uint,
    collateral: uint,
    interest-rate: uint,
    duration: uint,
    created-at: uint,
    funded-at: (optional uint),
    repaid-at: (optional uint),
    liquidated-at: (optional uint),
    status: (string-ascii 20)
  }
)

(define-map user-balances
  { user: principal }
  { balance: uint }
)

(define-map collateral-deposits
  { user: principal }
  { amount: uint }
)

(define-private (get-balance (user principal))
  (default-to u0 (get balance (map-get? user-balances { user: user })))
)

(define-private (set-balance (user principal) (amount uint))
  (map-set user-balances { user: user } { balance: amount })
)

(define-private (get-collateral (user principal))
  (default-to u0 (get amount (map-get? collateral-deposits { user: user })))
)

(define-private (set-collateral (user principal) (amount uint))
  (map-set collateral-deposits { user: user } { amount: amount })
)

(define-private (calculate-interest (principal-amount uint) (rate uint) (duration uint))
  (/ (* (* principal-amount rate) duration) u10000)
)

(define-private (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u10000)
)

(define-private (is-loan-expired (loan-id uint))
  (match (map-get? loans { loan-id: loan-id })
    loan-data
    (match (get funded-at loan-data)
      funded-time
      (let ((expiry-time (+ funded-time (get duration loan-data))))
        (> stacks-block-height expiry-time))
      false)
    false
  )
)

(define-public (deposit-funds (amount uint))
  (let ((current-balance (get-balance tx-sender)))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (set-balance tx-sender (+ current-balance amount))
    (ok true)
  )
)

(define-public (withdraw-funds (amount uint))
  (let ((current-balance (get-balance tx-sender)))
    (asserts! (>= current-balance amount) err-insufficient-balance)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (set-balance tx-sender (- current-balance amount))
    (ok true)
  )
)

(define-public (deposit-collateral (amount uint))
  (let ((current-collateral (get-collateral tx-sender)))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (set-collateral tx-sender (+ current-collateral amount))
    (ok true)
  )
)

(define-public (withdraw-collateral (amount uint))
  (let ((current-collateral (get-collateral tx-sender)))
    (asserts! (>= current-collateral amount) err-insufficient-balance)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (set-collateral tx-sender (- current-collateral amount))
    (ok true)
  )
)

(define-public (create-loan-request (amount uint) (collateral uint) (interest-rate uint) (duration uint))
  (let ((loan-id (var-get next-loan-id))
        (required-collateral (/ (* amount (var-get min-collateral-ratio)) u100))
        (user-collateral (get-collateral tx-sender)))
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= collateral required-collateral) err-insufficient-collateral)
    (asserts! (>= user-collateral collateral) err-insufficient-collateral)
    
    (map-set loans
      { loan-id: loan-id }
      {
        borrower: tx-sender,
        lender: none,
        amount: amount,
        collateral: collateral,
        interest-rate: interest-rate,
        duration: duration,
        created-at: stacks-block-height,
        funded-at: none,
        repaid-at: none,
        liquidated-at: none,
        status: "pending"
      }
    )
    
    (set-collateral tx-sender (- user-collateral collateral))
    (var-set next-loan-id (+ loan-id u1))
    (ok loan-id)
  )
)

(define-public (fund-loan (loan-id uint))
  (match (map-get? loans { loan-id: loan-id })
    loan-data
    (let ((lender-balance (get-balance tx-sender))
          (loan-amount (get amount loan-data))
          (platform-fee (calculate-platform-fee loan-amount)))
      (asserts! (is-eq (get status loan-data) "pending") err-loan-active)
      (asserts! (>= lender-balance (+ loan-amount platform-fee)) err-insufficient-balance)
      
      (try! (as-contract (stx-transfer? loan-amount tx-sender (get borrower loan-data))))
      (set-balance tx-sender (- lender-balance (+ loan-amount platform-fee)))
      (set-balance contract-owner (+ (get-balance contract-owner) platform-fee))
      
      (map-set loans
        { loan-id: loan-id }
        (merge loan-data {
          lender: (some tx-sender),
          funded-at: (some stacks-block-height),
          status: "active"
        })
      )
      (ok true)
    )
    err-not-found
  )
)

(define-public (repay-loan (loan-id uint))
  (match (map-get? loans { loan-id: loan-id })
    loan-data
    (let ((borrower (get borrower loan-data))
          (loan-amount (get amount loan-data))
          (interest-amount (calculate-interest loan-amount (get interest-rate loan-data) (get duration loan-data)))
          (total-repayment (+ loan-amount interest-amount))
          (collateral-amount (get collateral loan-data)))
      (asserts! (is-eq tx-sender borrower) err-unauthorized)
      (asserts! (is-eq (get status loan-data) "active") err-not-found)
      (asserts! (not (is-loan-expired loan-id)) err-loan-expired)
      
      (match (get lender loan-data)
        lender
        (begin
          (try! (stx-transfer? total-repayment tx-sender (as-contract tx-sender)))
          (try! (as-contract (stx-transfer? total-repayment tx-sender lender)))
          (try! (as-contract (stx-transfer? collateral-amount tx-sender borrower)))
          
          (map-set loans
            { loan-id: loan-id }
            (merge loan-data {
              repaid-at: (some stacks-block-height),
              status: "repaid"
            })
          )
          (ok true)
        )
        err-not-found
      )
    )
    err-not-found
  )
)

(define-public (liquidate-loan (loan-id uint))
  (match (map-get? loans { loan-id: loan-id })
    loan-data
    (let ((collateral-amount (get collateral loan-data)))
      (asserts! (is-eq (get status loan-data) "active") err-not-found)
      (asserts! (is-loan-expired loan-id) err-loan-active)
      
      (match (get lender loan-data)
        lender
        (begin
          (asserts! (is-eq tx-sender lender) err-unauthorized)
          (try! (as-contract (stx-transfer? collateral-amount tx-sender lender)))
          
          (map-set loans
            { loan-id: loan-id }
            (merge loan-data {
              liquidated-at: (some stacks-block-height),
              status: "liquidated"
            })
          )
          (ok true)
        )
        err-unauthorized
      )
    )
    err-not-found
  )
)

(define-public (cancel-loan-request (loan-id uint))
  (match (map-get? loans { loan-id: loan-id })
    loan-data
    (let ((borrower (get borrower loan-data))
          (collateral-amount (get collateral loan-data))
          (current-collateral (get-collateral borrower)))
      (asserts! (is-eq tx-sender borrower) err-unauthorized)
      (asserts! (is-eq (get status loan-data) "pending") err-loan-active)
      
      (set-collateral borrower (+ current-collateral collateral-amount))
      (map-set loans
        { loan-id: loan-id }
        (merge loan-data { status: "cancelled" })
      )
      (ok true)
    )
    err-not-found
  )
)

(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)

(define-public (set-min-collateral-ratio (new-ratio uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set min-collateral-ratio new-ratio)
    (ok true)
  )
)

(define-read-only (get-loan (loan-id uint))
  (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-user-balance (user principal))
  (get-balance user)
)

(define-read-only (get-user-collateral (user principal))
  (get-collateral user)
)

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

(define-read-only (get-min-collateral-ratio)
  (var-get min-collateral-ratio)
)

(define-read-only (get-next-loan-id)
  (var-get next-loan-id)
)

(define-read-only (calculate-total-repayment (loan-id uint))
  (match (map-get? loans { loan-id: loan-id })
    loan-data
    (let ((principal-amount (get amount loan-data))
          (interest-amount (calculate-interest principal-amount (get interest-rate loan-data) (get duration loan-data))))
      (some (+ principal-amount interest-amount))
    )
    none
  )
)
