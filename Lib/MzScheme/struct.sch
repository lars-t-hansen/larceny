;; This code depends on Auxlib/record.sch and Lib/MzScheme/inspector.sch

;; http://download.plt-scheme.org/doc/207/html/mzscheme/mzscheme-Z-H-4.html#node_chap_4

;; FIXME:
;;  - immutable-k-list is ignored.
;;  - auto-fields are broken
;;  - struct? isn't quite right.
;;  - make-struct-type should use struct-type-property guard proc
;;  - inherit things like inspectors, prop-value-lists, struct-procedures
;;  - make-struct-type should return constructors/accessors/mutators
;;    built by (make-struct-constructor...) etc.


;; These procedures are provided.
(define make-struct-type)
(define make-struct-type-property)
(define make-struct-field-accessor)
(define make-struct-field-mutator)

(define make-wrapped-waitable)
(define make-nack-guard-waitable)
(define make-poll-guard-waitable)

(define struct?)
(define struct-type?)
(define struct-type-property?)

(define struct-info)
(define struct-type-info)
(define struct->vector)

(define struct-mutator-procedure?)
(define struct-accessor-procedure?)
(define struct-predicate-procedure?)
(define struct-constructor-procedure?)

;; Consumes a struct instance and produces the proc-spec value
;; that was provided to make-struct-type when this instance's type
;; was created.
(define $sys.struct-proc-spec)

;; Given a structure instance s and a number i,
;; yield the value in the i-th field of s
;; : struct number -> value
(define $sys.struct-ref)

;; define-record is nowhere to be found.
(let* ((*rtd-type* (record-type-descriptor (make-record-type "" '())))
      
       ;; The struct-type-descriptor type is a subtype of the
       ;; record-type-descriptor type.  (Say that five times fast!)
       (*std-type* (make-record-type
                    "struct-type-descriptor"
                    '(auto-v prop-values inspector proc immutable-k-list)
                    *rtd-type*))
       (*stype-prop-type* (make-record-type
                           "struct-type-property-descriptor"
                           '(name guard-proc))))

  ;; Accessors for record type descriptors
  (define get-slots (record-accessor *rtd-type* 'slot-offsets))
  (define get-printer (record-accessor *rtd-type* 'printer))
  (define get-hier-vector (record-accessor *rtd-type* 'hierarchy-vector))
  (define get-hier-depth (record-accessor *rtd-type* 'hierarchy-depth))
  (define get-record-size (record-accessor *rtd-type* 'record-size))

  ;; Constructors / Accessors / Predicate for struct type descriptors
  (define make-stype (record-constructor *std-type*)) 
  (define stype-auto-v (record-accessor *std-type* 'auto-v))
  (define stype-prop-values (record-accessor *std-type* 'prop-values))
  (define stype-inspector (record-accessor *std-type* 'inspector))
  (define stype-proc (record-accessor *std-type* 'proc))
  (define stype-immutable-k-list
    (record-accessor *std-type* 'immutable-k-list))
  (define stype? (record-predicate *std-type*))

  ;; Constructors / Accessors / Predicate for struct-type-property
  ;; descriptors
  (define make-stype-prop (record-constructor *stype-prop-type*))
  (define stype-prop-name (record-accessor *stype-prop-type*
                                    'name))
  (define stype-prop-guard-proc (record-accessor *stype-prop-type*
                                          'guard-proc))
  (define stype-prop? (record-predicate *stype-prop-type*))
  

  ;; These four bindings are temporary.  They'll be set to procedures
  ;; that produce structure-procedures below.
  (define struct-constructor record-constructor)
  (define struct-predicate record-predicate)
  (define struct-indexer record-indexer)
  (define struct-mutator record-mutator)

  (define make-struct-type*
    (let ((offset->name
           (lambda (n) (string->symbol
                        (string-append "field-" (number->string n))))))
      (lambda (name super init-field-k auto-field-k . rest)
        ;; no opt-lambda, sorry...
        (let* ((defaults '(#f ;; auto-fill value
                           () ;; property value list
                           ;; go one up to get an opaque type
                           ($sys.inspector->superior (current-inspector))
                           #f ;; structure procedure
                           ())) ;; list of immutable field indices
               (opts (append rest
                             (drop (length rest) defaults)))
               (opts (list->vector opts)))
          
          (let ((auto-v (vector-ref opts 0))
                (prop-values (vector-ref opts 1))
                (inspector (vector-ref opts 2))
                (proc-spec (vector-ref opts 3))
                (immutable-k-list (vector-ref opts 4))
                
                (field-names
                 (map offset->name
                      (nats-to (+ init-field-k auto-field-k)))))
            
            ;; Make a record-type, and then use accessors to transfer
            ;; the data into a struct-type
            (let ((rtd (make-record-type (symbol->string name)
                                         field-names
                                         super)))
              (let ((hierarchy-vec (get-hier-vector rtd))
                    (hierarchy-depth (get-hier-depth rtd)))
                    
                (let ((st (make-stype
                           (record-type-name rtd)
                           (get-slots rtd)
                           (get-printer rtd)
                           (get-record-size rtd)
                           hierarchy-vec
                           hierarchy-depth
                           ;;
                           auto-v
                           prop-values
                           inspector
                           proc-spec
                           immutable-k-list)))
                  ;; Still need to invoke a bit of voodoo:
                  ;; make-record-type leaves the hierarchy-vector entry
                  ;; as a record-type-descriptor, but we want our
                  ;; shiny new struct-type-descriptor there instead.
                  (vector-set! hierarchy-vec hierarchy-depth st)

                  (let ((constructor
                         (struct-constructor st))
                        (predicate
                         (struct-predicate st))
                        (accessor
                         (struct-indexer st))
                        (mutator
                         (struct-mutator st)))
                
                    (values st
                            constructor
                            predicate
                            accessor
                            mutator))))))))))

  (define make-struct-type-property*
    (case-lambda
      ((name) (make-struct-type-property* name #f))
      ((name guard-proc)
       (let ((prop:p (make-record-type (symbol->string name)
                                       '()
                                       *stype-prop-type*)))
         (define (p? x)
           (cond ((struct-instance? x)
                  (p? (record-type-descriptor x)))
                 ((struct-type? x)
                  (let ((prop-vals (stype-prop-values x)))
                    (if (assq prop:p prop-vals)
                        #t
                        #f)))
                 (else #f)))

         (define (p-ref x)
           (cond ((struct-instance? x)
                  (p-ref (record-type-descriptor x)))
                 ((struct-type? x)
                  (let ((prop-vals (stype-prop-values x)))
                    (cond ((assq prop:p prop-vals) => cdr)
                          (else (p-ref 0))))) ;; trigger the error case
                 (else
                  (error "make-struct-type-property: exn:application:type"))))
           
         (values prop:p p? p-ref)
         ))))
  
  (define make-struct-field-accessor* (undefined))
  (define make-struct-field-mutator* (undefined))
  
  (define make-wrapped-waitable* (undefined))
  (define make-nack-guard-waitable* (undefined))
  (define make-poll-guard-waitable* (undefined))

  ;; FIXME:  This isn't right.  struct? only yields true when
  ;; struct->vector would produce a vector with some field values exposed.
  ;; Weird.  See MzScheme manual 4.8.
  (define struct?* struct-instance?)

  ;; this is internal
  (define struct-instance?
    (lambda (obj) (and (record? obj)
                  (struct-type? (record-type-descriptor obj)))))
  
  (define struct-type?*
    (lambda (t) (stype? t)))
  
  (define struct-type-property?* stype-prop?)
  
  (define struct-info* (undefined))
  (define struct-type-info* (undefined))
  (define struct->vector* (undefined))
  
  (define struct-mutator-procedure?* (undefined))
  (define struct-accessor-procedure?*
    (lambda (obj) (acc-proc? obj)))
  (define struct-predicate-procedure?* (undefined))
  (define struct-constructor-procedure?* (undefined))

  ;; Random utilities that don't belong above.
  ;; drop the first n elements of lst
  (define (drop n lst)
    (if (zero? n)
        lst
        (drop (- n 1) (cdr lst))))
  
  ;; generate (list 0 1 ... n-1)
  (define (nats-to n)
    (let loop ((c (- n 1))
               (l '()))
      (if (< c 0)
          l
          (loop (- c 1)
                (cons c l)))))

  ;; given an instance, return its type's proc-spec
  (define sys:struct-proc-spec
    (lambda (instance)
      (let ((type (record-type-descriptor instance)))
        (stype-proc type))))

  ;; index into an arbitrary structure instance.
  (define sys:struct-ref
    ;; the magic number couples this code with the record
    ;; implementation.
    (let ((struct-field-offset 1))
      (lambda (instance index)
        (vector-like-ref instance (+ index struct-field-offset)))))

  ;;; Begin voodoo to get the procedures returned by
  ;;; make-struct-type to be structure procedures
  (define-values (struct:acc-proc make-acc-proc acc-proc? acc-proc-ref _)
    (make-struct-type* 'struct-accessor-procedure
                      #f  ;no super
                      2   ;2 init fields
                      0   ;0 auto fields
                      #f  ;auto-value
                      '() ; prop values
                      (make-inspector)
                      0   ; proc-spec
                      '()))
  (set! struct-indexer
        (lambda (stype) (make-acc-proc (record-indexer stype) 'indexer))) 
  
  
  ;; Hook up the implementation with the interface.
  (set! make-struct-type make-struct-type*)
  (set! make-struct-type-property make-struct-type-property*)
  (set! make-struct-field-accessor make-struct-field-accessor*)
  (set! make-struct-field-mutator make-struct-field-mutator*)
  
  (set! make-wrapped-waitable make-wrapped-waitable*)
  (set! make-nack-guard-waitable make-nack-guard-waitable*)
  (set! make-poll-guard-waitable make-poll-guard-waitable*)
  
  (set! struct? struct?*)
  (set! struct-type? struct-type?*)
  (set! struct-type-property? struct-type-property?*)
  
  (set! struct-info struct-info*)
  (set! struct-type-info struct-type-info*)
  (set! struct->vector struct->vector*)
  
  (set! struct-mutator-procedure? struct-mutator-procedure?*)
  (set! struct-accessor-procedure? struct-accessor-procedure?*)
  (set! struct-predicate-procedure? struct-predicate-procedure?*)
  (set! struct-constructor-procedure? struct-constructor-procedure?*)

  (set! $sys.struct-proc-spec sys:struct-proc-spec)
  (set! $sys.struct-ref sys:struct-ref)

  )
  
;; Quick and dirty test case
;; define-values is in Lib/MzScheme/macros.sch

(define-values (struct:tup make-tup tup? tup-ref tup-set!)
  (make-struct-type 'tup #f 2 0))

(define-values (struct:triple make-triple triple? triple-ref triple-set!)
  (make-struct-type 'triple struct:tup 1 0))

(define-values (prop:p p? p-ref) (make-struct-type-property 'p))

(define-values (struct:a make-a a? a-ref a-set!) 
  (make-struct-type 'a #f 2 1 'uninitialized (list (cons prop:p 8))))

;(p? struct:a) ; => #t 
;(p? 13) ; => #f 
;(define an-a (make-a 'x 'y)) 
;(p? an-a) ; => #t
;(p-ref an-a) ; => 8

(define-values (struct:b make-b b? b-ref b-set!) 
  (make-struct-type 'b #f 0 0 #f)) 
;(p? struct:b) ; => #f