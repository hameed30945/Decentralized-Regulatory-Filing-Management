;; Entity Verification Contract
;; Validates regulated businesses on the blockchain

(define-data-var admin principal tx-sender)

;; Entity status: 0 = unverified, 1 = verified, 2 = suspended
(define-map entities principal
  {
    status: uint,
    name: (string-ascii 100),
    registration-number: (string-ascii 50),
    jurisdiction: (string-ascii 50),
    verification-date: uint
  }
)

(define-read-only (get-entity (entity-id principal))
  (default-to
    {
      status: u0,
      name: "",
      registration-number: "",
      jurisdiction: "",
      verification-date: u0
    }
    (map-get? entities entity-id)
  )
)

(define-public (register-entity (name (string-ascii 100)) (registration-number (string-ascii 50)) (jurisdiction (string-ascii 50)))
  (begin
    (asserts! (is-none (map-get? entities tx-sender)) (err u1)) ;; Entity already exists
    (ok (map-set entities tx-sender
      {
        status: u0, ;; Initially unverified
        name: name,
        registration-number: registration-number,
        jurisdiction: jurisdiction,
        verification-date: u0
      }
    ))
  )
)

(define-public (verify-entity (entity-id principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can verify
    (asserts! (is-some (map-get? entities entity-id)) (err u404)) ;; Entity must exist
    (let ((entity (unwrap-panic (map-get? entities entity-id))))
      (ok (map-set entities entity-id
        (merge entity {
          status: u1,
          verification-date: block-height
        })
      ))
    )
  )
)

(define-public (suspend-entity (entity-id principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can suspend
    (asserts! (is-some (map-get? entities entity-id)) (err u404)) ;; Entity must exist
    (let ((entity (unwrap-panic (map-get? entities entity-id))))
      (ok (map-set entities entity-id
        (merge entity {status: u2})
      ))
    )
  )
)

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only current admin can transfer
    (ok (var-set admin new-admin))
  )
)
