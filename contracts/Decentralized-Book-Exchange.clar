(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-STATUS (err u422))
(define-constant ERR-EXPIRED (err u410))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))

(define-constant CONTRACT-OWNER tx-sender)
(define-constant PLATFORM-FEE u100)
(define-constant MIN-ESCROW-AMOUNT u1000000)
(define-constant MAX-LENDING-PERIOD u144)

(define-data-var next-book-id uint u1)
(define-data-var next-trade-id uint u1)
(define-data-var platform-earnings uint u0)

(define-map books 
  uint 
  {
    owner: principal,
    title: (string-ascii 100),
    author: (string-ascii 50),
    isbn: (string-ascii 20),
    condition: (string-ascii 20),
    trade-type: (string-ascii 10),
    price: uint,
    available: bool,
    created-at: uint
  }
)

(define-map trades
  uint
  {
    book-id: uint,
    lender: principal,
    borrower: principal,
    escrow-amount: uint,
    start-block: uint,
    end-block: uint,
    status: (string-ascii 20),
    trade-type: (string-ascii 10)
  }
)

(define-map user-ratings
  principal
  {
    total-rating: uint,
    trade-count: uint,
    reputation: uint
  }
)

(define-map escrow-deposits
  uint
  uint
)

(define-public (list-book 
  (title (string-ascii 100))
  (author (string-ascii 50))
  (isbn (string-ascii 20))
  (condition (string-ascii 20))
  (trade-type (string-ascii 10))
  (price uint))
  (let ((book-id (var-get next-book-id)))
    (asserts! (or (is-eq trade-type "lend") (is-eq trade-type "sell")) ERR-INVALID-STATUS)
    (asserts! (> price u0) ERR-INVALID-AMOUNT)
    (map-set books book-id {
      owner: tx-sender,
      title: title,
      author: author,
      isbn: isbn,
      condition: condition,
      trade-type: trade-type,
      price: price,
      available: true,
      created-at: stacks-block-height
    })
    (var-set next-book-id (+ book-id u1))
    (ok book-id)
  )
)

(define-public (update-book-availability (book-id uint) (available bool))
  (let ((book (unwrap! (map-get? books book-id) ERR-NOT-FOUND)))
    (asserts! (is-eq (get owner book) tx-sender) ERR-UNAUTHORIZED)
    (map-set books book-id (merge book {available: available}))
    (ok true)
  )
)

(define-public (initiate-trade (book-id uint) (lending-period uint))
  (let (
    (book (unwrap! (map-get? books book-id) ERR-NOT-FOUND))
    (trade-id (var-get next-trade-id))
    (escrow-amount (if (is-eq (get trade-type book) "lend") 
                      (+ (get price book) MIN-ESCROW-AMOUNT)
                      (get price book)))
  )
    (asserts! (get available book) ERR-INVALID-STATUS)
    (asserts! (not (is-eq tx-sender (get owner book))) ERR-UNAUTHORIZED)
    (asserts! (>= (stx-get-balance tx-sender) escrow-amount) ERR-INSUFFICIENT-FUNDS)
    (asserts! (or 
                (is-eq (get trade-type book) "sell")
                (and (is-eq (get trade-type book) "lend") 
                     (<= lending-period MAX-LENDING-PERIOD))) ERR-INVALID-AMOUNT)
    
    (try! (stx-transfer? escrow-amount tx-sender (as-contract tx-sender)))
    
    (map-set escrow-deposits trade-id escrow-amount)
    (map-set trades trade-id {
      book-id: book-id,
      lender: (get owner book),
      borrower: tx-sender,
      escrow-amount: escrow-amount,
      start-block: stacks-block-height,
      end-block: (if (is-eq (get trade-type book) "lend") 
                    (+ stacks-block-height lending-period)
                    stacks-block-height),
      status: "pending",
      trade-type: (get trade-type book)
    })
    
    (map-set books book-id (merge book {available: false}))
    (var-set next-trade-id (+ trade-id u1))
    (ok trade-id)
  )
)

(define-public (approve-trade (trade-id uint))
  (let ((trade (unwrap! (map-get? trades trade-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get lender trade)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status trade) "pending") ERR-INVALID-STATUS)
    
    (map-set trades trade-id (merge trade {status: "active"}))
    
    (if (is-eq (get trade-type trade) "sell")
      (begin
        (try! (as-contract (stx-transfer? 
          (- (get escrow-amount trade) PLATFORM-FEE) 
          tx-sender 
          (get lender trade))))
        (var-set platform-earnings (+ (var-get platform-earnings) PLATFORM-FEE))
        (map-set trades trade-id (merge trade {status: "completed"}))
      )
      true
    )
    (ok true)
  )
)

(define-public (reject-trade (trade-id uint))
  (let ((trade (unwrap! (map-get? trades trade-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get lender trade)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status trade) "pending") ERR-INVALID-STATUS)
    
    (try! (as-contract (stx-transfer? 
      (get escrow-amount trade) 
      tx-sender 
      (get borrower trade))))
    
    (map-set trades trade-id (merge trade {status: "rejected"}))
    (try! (update-book-availability (get book-id trade) true))
    (ok true)
  )
)

(define-public (return-book (trade-id uint))
  (let ((trade (unwrap! (map-get? trades trade-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get borrower trade)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status trade) "active") ERR-INVALID-STATUS)
    (asserts! (is-eq (get trade-type trade) "lend") ERR-INVALID-STATUS)
    
    (map-set trades trade-id (merge trade {status: "returned"}))
    (ok true)
  )
)

(define-public (confirm-return (trade-id uint) (rating uint))
  (let ((trade (unwrap! (map-get? trades trade-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get lender trade)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status trade) "returned") ERR-INVALID-STATUS)
    (asserts! (<= rating u5) ERR-INVALID-AMOUNT)
    
    (let ((lending-fee (/ (get escrow-amount trade) u10)))
      (try! (as-contract (stx-transfer? 
        (- (get escrow-amount trade) lending-fee) 
        tx-sender 
        (get borrower trade))))
      (try! (as-contract (stx-transfer? 
        (- lending-fee PLATFORM-FEE) 
        tx-sender 
        (get lender trade))))
      (var-set platform-earnings (+ (var-get platform-earnings) PLATFORM-FEE))
    )
    
    (unwrap! (update-user-rating (get borrower trade) rating) ERR-INVALID-AMOUNT)
    (map-set trades trade-id (merge trade {status: "completed"}))
    (try! (update-book-availability (get book-id trade) true))
    (ok true)
  )
)

(define-public (claim-overdue (trade-id uint))
  (let ((trade (unwrap! (map-get? trades trade-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get lender trade)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status trade) "active") ERR-INVALID-STATUS)
    (asserts! (is-eq (get trade-type trade) "lend") ERR-INVALID-STATUS)
    (asserts! (> stacks-block-height (get end-block trade)) ERR-INVALID-STATUS)
    
    (try! (as-contract (stx-transfer? 
      (- (get escrow-amount trade) PLATFORM-FEE) 
      tx-sender 
      (get lender trade))))
    (var-set platform-earnings (+ (var-get platform-earnings) PLATFORM-FEE))
    
    (map-set trades trade-id (merge trade {status: "overdue-claimed"}))
    (ok true)
  )
)

(define-public (dispute-trade (trade-id uint))
  (let ((trade (unwrap! (map-get? trades trade-id) ERR-NOT-FOUND)))
    (asserts! (or (is-eq tx-sender (get lender trade)) 
                  (is-eq tx-sender (get borrower trade))) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status trade) "active") ERR-INVALID-STATUS)
    
    (map-set trades trade-id (merge trade {status: "disputed"}))
    (ok true)
  )
)

(define-public (resolve-dispute (trade-id uint) (winner (string-ascii 10)))
  (let ((trade (unwrap! (map-get? trades trade-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status trade) "disputed") ERR-INVALID-STATUS)
    (asserts! (or (is-eq winner "lender") (is-eq winner "borrower")) ERR-INVALID-STATUS)
    
    (if (is-eq winner "lender")
      (try! (as-contract (stx-transfer? 
        (- (get escrow-amount trade) PLATFORM-FEE) 
        tx-sender 
        (get lender trade))))
      (try! (as-contract (stx-transfer? 
        (- (get escrow-amount trade) PLATFORM-FEE) 
        tx-sender 
        (get borrower trade))))
    )
    (var-set platform-earnings (+ (var-get platform-earnings) PLATFORM-FEE))
    
    (map-set trades trade-id (merge trade {status: "dispute-resolved"}))
    (ok true)
  )
)

(define-private (update-user-rating (user principal) (rating uint))
  (let ((current-rating (default-to {total-rating: u0, trade-count: u0, reputation: u0} 
                                   (map-get? user-ratings user))))
    (let ((new-total (+ (get total-rating current-rating) rating))
          (new-count (+ (get trade-count current-rating) u1)))
      (map-set user-ratings user {
        total-rating: new-total,
        trade-count: new-count,
        reputation: (/ new-total new-count)
      })
      (ok true)
    )
  )
)

(define-read-only (get-book (book-id uint))
  (ok (map-get? books book-id))
)

(define-read-only (get-trade (trade-id uint))
  (ok (map-get? trades trade-id))
)

(define-read-only (get-user-rating (user principal))
  (ok (map-get? user-ratings user))
)

(define-read-only (get-platform-earnings)
  (ok (var-get platform-earnings))
)

(define-read-only (get-books-by-owner (owner principal))
  (ok (filter check-book-owner (list 
    u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
  )))
)

(define-private (check-book-owner (book-id uint))
  (match (map-get? books book-id)
    book (is-eq (get owner book) tx-sender)
    false
  )
)

(define-read-only (is-trade-overdue (trade-id uint))
  (match (map-get? trades trade-id)
    trade (and 
            (is-eq (get trade-type trade) "lend")
            (is-eq (get status trade) "active")
            (> stacks-block-height (get end-block trade)))
    false
  )
)
