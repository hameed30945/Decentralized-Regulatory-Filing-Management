;; Document Preparation Contract
;; Manages creation of regulatory filings

(define-data-var admin principal tx-sender)

;; Document templates map: template-id -> template details
(define-map document-templates uint
  {
    title: (string-ascii 100),
    description: (string-utf8 500),
    requirement-id: uint,
    schema: (string-utf8 1000), ;; JSON schema for the document
    active: bool
  }
)

;; Documents map: document-id -> document details
(define-map documents uint
  {
    entity: principal,
    template-id: uint,
    requirement-id: uint,
    content-hash: (buff 32), ;; Hash of the document content (stored off-chain)
    status: uint, ;; 0 = draft, 1 = finalized, 2 = submitted
    created-at: uint,
    updated-at: uint
  }
)

(define-data-var next-template-id uint u1)
(define-data-var next-document-id uint u1)

(define-read-only (get-document-template (template-id uint))
  (map-get? document-templates template-id)
)

(define-read-only (get-document (document-id uint))
  (map-get? documents document-id)
)

(define-public (add-document-template (title (string-ascii 100)) (description (string-utf8 500)) (requirement-id uint) (schema (string-utf8 1000)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can add templates
    (let ((template-id (var-get next-template-id)))
      (map-set document-templates template-id
        {
          title: title,
          description: description,
          requirement-id: requirement-id,
          schema: schema,
          active: true
        }
      )
      (var-set next-template-id (+ template-id u1))
      (ok template-id)
    )
  )
)

(define-public (create-document (template-id uint) (requirement-id uint) (content-hash (buff 32)))
  (begin
    (asserts! (is-some (map-get? document-templates template-id)) (err u404)) ;; Template must exist
    (let ((document-id (var-get next-document-id)))
      (map-set documents document-id
        {
          entity: tx-sender,
          template-id: template-id,
          requirement-id: requirement-id,
          content-hash: content-hash,
          status: u0, ;; Draft
          created-at: block-height,
          updated-at: block-height
        }
      )
      (var-set next-document-id (+ document-id u1))
      (ok document-id)
    )
  )
)

(define-public (update-document (document-id uint) (content-hash (buff 32)))
  (begin
    (asserts! (is-some (map-get? documents document-id)) (err u404)) ;; Document must exist
    (let ((document (unwrap-panic (map-get? documents document-id))))
      (asserts! (is-eq tx-sender (get entity document)) (err u403)) ;; Only owner can update
      (asserts! (< (get status document) u2) (err u400)) ;; Cannot update submitted documents
      (ok (map-set documents document-id
        (merge document {
          content-hash: content-hash,
          updated-at: block-height
        })
      ))
    )
  )
)

(define-public (finalize-document (document-id uint))
  (begin
    (asserts! (is-some (map-get? documents document-id)) (err u404)) ;; Document must exist
    (let ((document (unwrap-panic (map-get? documents document-id))))
      (asserts! (is-eq tx-sender (get entity document)) (err u403)) ;; Only owner can finalize
      (asserts! (is-eq (get status document) u0) (err u400)) ;; Must be in draft status
      (ok (map-set documents document-id
        (merge document {
          status: u1, ;; Finalized
          updated-at: block-height
        })
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
