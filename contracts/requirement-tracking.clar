;; Requirement Tracking Contract
;; Records compliance obligations for regulated entities

(define-data-var admin principal tx-sender)

;; Requirements map: requirement-id -> requirement details
(define-map requirements uint
  {
    title: (string-ascii 100),
    description: (string-utf8 500),
    jurisdiction: (string-ascii 50),
    frequency: uint, ;; in blocks (e.g., monthly, quarterly)
    active: bool
  }
)

;; Entity requirements map: entity -> requirement-id -> due date
(define-map entity-requirements { entity: principal, requirement-id: uint }
  {
    due-date: uint, ;; block height when next filing is due
    last-filed: uint ;; block height when last filed (0 if never)
  }
)

(define-data-var next-requirement-id uint u1)

(define-read-only (get-requirement (requirement-id uint))
  (map-get? requirements requirement-id)
)

(define-read-only (get-entity-requirement (entity principal) (requirement-id uint))
  (map-get? entity-requirements { entity: entity, requirement-id: requirement-id })
)

(define-public (add-requirement (title (string-ascii 100)) (description (string-utf8 500)) (jurisdiction (string-ascii 50)) (frequency uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can add requirements
    (let ((requirement-id (var-get next-requirement-id)))
      (map-set requirements requirement-id
        {
          title: title,
          description: description,
          jurisdiction: jurisdiction,
          frequency: frequency,
          active: true
        }
      )
      (var-set next-requirement-id (+ requirement-id u1))
      (ok requirement-id)
    )
  )
)

(define-public (assign-requirement (entity principal) (requirement-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can assign requirements
    (asserts! (is-some (map-get? requirements requirement-id)) (err u404)) ;; Requirement must exist
    (let ((requirement (unwrap-panic (map-get? requirements requirement-id))))
      (asserts! (get active requirement) (err u400)) ;; Requirement must be active
      (ok (map-set entity-requirements
        { entity: entity, requirement-id: requirement-id }
        {
          due-date: (+ block-height (get frequency requirement)),
          last-filed: u0
        }
      ))
    )
  )
)

(define-public (update-requirement-status (requirement-id uint) (active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can update requirements
    (asserts! (is-some (map-get? requirements requirement-id)) (err u404)) ;; Requirement must exist
    (let ((requirement (unwrap-panic (map-get? requirements requirement-id))))
      (ok (map-set requirements requirement-id
        (merge requirement {active: active})
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
