;; SRFI-19: Time Data Types and Procedures.
;;
;; $Id$
;;
;; Reference implementation taken from srfi.schemers.org on
;; 2004-01-04, subsequently lightly adapted to Larceny.
;;
;; I've attemted to isolate platform dependencies by grouping them,
;; search for 'BEGIN PLATFORM DEPENDENT'.  There are two such blocks.

;; Copyright (C) I/NET, Inc. (2000, 2002, 2003). All Rights Reserved. 
;; 
;; This document and translations of it may be copied and furnished to
;; others, and derivative works that comment on or otherwise explain
;; it or assist in its implementation may be prepared, copied,
;; published and distributed, in whole or in part, without restriction
;; of any kind, provided that the above copyright notice and this
;; paragraph are included on all such copies and derivative works.
;; However, this document itself may not be modified in any way, such
;; as by removing the copyright notice or references to the Scheme
;; Request For Implementation process or editors, except as needed for
;; the purpose of developing SRFIs in which case the procedures for
;; copyrights defined in the SRFI process must be followed, or as
;; required to translate it into languages other than English.
;; 
;; The limited permissions granted above are perpetual and will not be
;; revoked by the authors or their successors or assigns.
;; 
;; This document and the information contained herein is provided on
;; an "AS IS" basis and THE AUTHOR AND THE SRFI EDITORS DISCLAIM ALL
;; WARRANTIES, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY
;; WARRANTY THAT THE USE OF THE INFORMATION HEREIN WILL NOT INFRINGE
;; ANY RIGHTS OR ANY IMPLIED WARRANTIES OF MERCHANTABILITY OR FITNESS
;; FOR A PARTICULAR PURPOSE.

;; -- Bug fixes.
;;
;; MAKE-TIME had parameters seconds and nanoseconds reversed; change all
;;           references in file to match.  Will F: 2002-10-15
;;
;; DATE-YEAR-DAY returned the wrong day; tm:year-day fixed to do the right
;;               thing. Will F: 2002-10-15
;;               It also called an undefined error procedure.
;;
;; DISPLAYING procedure removed. Will F: 2002-10-15.
;;
;; TM:NANO constant corrected. 2002-11-04.
;;
;; The following fixes by Will Fitzgerald, February, 2003.
;;  -- Thanks to Steven Ma and others.
;;
;; (CURRENT-TIME 'TIME-THREAD) added.
;;
;; TIME-RESOLUTION for TIME-PROCESS added. 
;;
;; TIME comparison procedures (time=?, etc. fixed. 
;;
;; Corrected errors in converting between TAI and UTC time.
;;
;; TAI and UTC date converters no longer look at leap seconds,
;; which was an error.
;;
;; corrections to calls to tm:time-error
;;
;; timezone offset not used in date->time-utc and date->julian-day
;;
;; typos in tm:integer-reader-exact, tm:string->date,
;; time-monotonic->time-utc!, tm:char->int fixed
;;
;; corrected "~k", "~f" formatting for date->string (includes fix for
;; "~4"
;;
;; 'split-real' fixed.
;;
;; fixed julian-day->time-utc and variants.
;;
;; changes 2003-02-26, based on comments by Martin Gasbichler.
;; 
;; moronic, overly complicated COPY-TIME procedure changed
;; to simple version suggested by Martin Gasbichler.
;;
;; To provide more portability, changed #\Space to #\space
;; and #\tab to #\Tab to (integer->char 9)
;;
;; changed arity-3 calls to / and - to arity 2 calls (again,
;; for more general portability). 
;;
;; split-real fixed again -- by removing it, and using
;; 'fractional part'. Will Fitzgerald 5/16/2003.
;; --------------------------------------------------------------

(library (srfi :19 time)

  (export time-duration time-monotonic time-process time-tai
          time-thread time-utc
          current-date current-julian-day current-modified-julian-day
          current-time time-resolution
          make-time time? time-type time-nanosecond time-second
          set-time-type! set-time-nanosecond! set-time-second!
          copy-time
          time<=? time<? time=? time>=? time>?
          time-difference time-difference!
          add-duration add-duration!
          subtract-duration subtract-duration!
          make-date date? date-nanosecond date-second
          date-minute date-hour date-day date-month date-year
          date-zone-offset date-year-day date-week-day date-week-number
          date->julian-day date->modified-julian-day
          date->time-monotonic date->time-tai date->time-utc
          julian-day->date julian-day->time-monotonic
          julian-day->time-tai julian-day->time-utc
          modified-julian-day->date modified-julian-day->time-monotonic
          modified-julian-day->time-tai modified-julian-day->time-utc
          time-monotonic->date time-monotonic->julian-day
          time-monotonic->modified-julian-day
          time-monotonic->time-tai  time-monotonic->time-tai!
          time-monotonic->time-utc  time-monotonic->time-utc!
          time-tai->date time-tai->julian-day
          time-tai->modified-julian-day
          time-tai->time-monotonic time-tai->time-monotonic!
          time-tai->time-utc time-tai->time-utc!
          time-utc->date time-utc->julian-day
          time-utc->modified-julian-day
          time-utc->time-monotonic time-utc->time-monotonic!
          time-utc->time-tai time-utc->time-tai!
          date->string string->date)

  (import (rnrs base)
          (rnrs unicode)
          (rnrs lists)
          (rnrs control)
          (only (rnrs io ports) get-line)
          (rnrs io simple)
          (rnrs mutable-strings)
          (rnrs r5rs)
          (srfi :6 basic-string-ports)
          (srfi :8 receive)
          (srfi :9 records)
          (primitives r5rs:require
                      current-utc-time timezone-offset
                      memstats memstats-system-time memstats-user-time
                      memstats-gc-total-cpu-time))

;; BEGIN PLATFORM DEPENDENT

(define ignored (r5rs:require 'time))        ; CURRENT-TIME and TIMEZONE-OFFSET
(define larceny/current-time current-utc-time)
(define larceny/timezone-offset timezone-offset)

(define current-process-milliseconds
  (lambda ()
    (let ((m (memstats)))
      (+ (memstats-system-time m) (memstats-user-time m)))))

(define current-gc-milliseconds
  (lambda ()
    (memstats-gc-total-cpu-time (memstats))))

(define read-line get-line)

;; END PLATFORM DEPENDENT

;; This was called :OPTIONAL but is incompatible with Shivers's
;; macro by that name, so has been renamed as :OPTIONAL-19

(define-syntax :optional-19
  (syntax-rules ()
    ((_ val default-value)
     (if (null? val) default-value (car val)))))

(define time-tai 'time-tai)
(define time-utc 'time-utc)
(define time-monotonic 'time-monotonic)
(define time-thread 'time-thread)
(define time-process 'time-process)
(define time-duration 'time-duration)

;; example of extension (MZScheme specific)
(define time-gc 'time-gc)

;;-- LOCALE dependent constants

(define tm:locale-number-separator ".")

(define tm:locale-abbr-weekday-vector (vector "Sun" "Mon" "Tue" "Wed"
                                              "Thu" "Fri" "Sat")) 
(define tm:locale-long-weekday-vector (vector "Sunday" "Monday"
                                              "Tuesday" "Wednesday"
                                              "Thursday" "Friday"
                                              "Saturday"))
;; note empty string in 0th place. 
(define tm:locale-abbr-month-vector   (vector "" "Jan" "Feb" "Mar"
                                              "Apr" "May" "Jun" "Jul"
                                              "Aug" "Sep" "Oct" "Nov"
                                              "Dec")) 
(define tm:locale-long-month-vector   (vector "" "January" "February"
                                              "March" "April" "May"
                                              "June" "July" "August"
                                              "September" "October"
                                              "November" "December")) 

(define tm:locale-pm "PM")
(define tm:locale-am "AM")

;; See date->string
(define tm:locale-date-time-format "~a ~b ~d ~H:~M:~S~z ~Y")
(define tm:locale-short-date-format "~m/~d/~y")
(define tm:locale-time-format "~H:~M:~S")
(define tm:iso-8601-date-time-format "~Y-~m-~dT~H:~M:~S~z")
;;-- Miscellaneous Constants.
;;-- only the tm:tai-epoch-in-jd might need changing if
;;   a different epoch is used.

(define tm:nano (expt 10 9))
(define tm:sid  86400)    ; seconds in a day
(define tm:sihd 43200)    ; seconds in a half day
(define tm:tai-epoch-in-jd 4881175/2) ; julian day number for 'the epoch'


;;; A Very simple Error system for the time procedures
;;; 
(define tm:time-error-types
  '(invalid-clock-type
    unsupported-clock-type
    incompatible-time-types
    not-duration
    dates-are-immutable
    bad-date-format-string
    bad-date-template-string
    invalid-month-specification
    ))

(define (tm:time-error caller type value)
  (if (member type tm:time-error-types)
      (if value
          (error caller ": TIME-ERROR type " type ": " value)
          (error caller ": TIME-ERROR type " type))
      (error caller ": TIME-ERROR unsupported error type " type)))

;; A table of leap seconds
;; See ftp://maia.usno.navy.mil/ser7/tai-utc.dat
;; and update as necessary.
;; this procedures reads the file in the abover
;; format and creates the leap second table
;; it also calls the almost standard, but not R5 procedures read-line 
;; & open-input-string
;; ie (set! tm:leap-second-table (tm:read-tai-utc-date "tai-utc.dat"))

(define (tm:read-tai-utc-data filename)
  (define (convert-jd jd)
    (* (- (inexact->exact jd) tm:tai-epoch-in-jd) tm:sid))
  (define (convert-sec sec)
    (inexact->exact sec))
  (let ( (port (open-input-file filename))
         (table '()) )
    (let loop ((line (read-line port)))
      (if (not (eof-object? line))
          (begin
            (let* ( (data (read (open-input-string (string-append "(" line ")")))) 
                    (year (car data))
                    (jd   (cadddr (cdr data)))
                    (secs (cadddr (cdddr data))) )
              (if (>= year 1972)
                  (set! table (cons (cons (convert-jd jd) (convert-sec secs)) table)))
              (loop (read-line port))))))
    table))

;; each entry is ( utc seconds since epoch . # seconds to add for tai )
;; note they go higher to lower, and end in 1972.
(define tm:leap-second-table
  '((1136073600 . 33)
    (915148800 . 32)
    (867715200 . 31)
    (820454400 . 30)
    (773020800 . 29)
    (741484800 . 28)
    (709948800 . 27)
    (662688000 . 26)
    (631152000 . 25)
    (567993600 . 24)
    (489024000 . 23)
    (425865600 . 22)
    (394329600 . 21)
    (362793600 . 20)
    (315532800 . 19)
    (283996800 . 18)
    (252460800 . 17)
    (220924800 . 16)
    (189302400 . 15)
    (157766400 . 14)
    (126230400 . 13)
    (94694400  . 12)
    (78796800  . 11)
    (63072000  . 10)))

(define (read-leap-second-table filename)
  (set! tm:leap-second-table (tm:read-tai-utc-data filename))
  (values))


(define (tm:leap-second-delta utc-seconds)
  (letrec ( (lsd (lambda (table) 
                   (cond
                    ((>= utc-seconds (caar table))
                     (cdar table))
                    (else (lsd (cdr table)))))) )
    (if (< utc-seconds  (* (- 1972 1970) 365 tm:sid)) 0
        (lsd  tm:leap-second-table))))

;; going from tai seconds to utc seconds ... 
(define (tm:leap-second-neg-delta tai-seconds)
  (letrec ( (lsd (lambda (table)
                   (cond ((null? table) 0)
                         ((<= (cdar table) (- tai-seconds (caar table)))
                          (cdar table))
                         (else (lsd (cdr table)))))) )
    (if (< tai-seconds  (* (- 1972 1970) 365 tm:sid)) 0
        (lsd  tm:leap-second-table))))


;;; the time structure; creates the accessors, too.
;;; wf: changed to match srfi documentation. 
;;; uses mzscheme structures & inspectors

;(define-struct time (type nanosecond second) (make-inspector))

(define-record-type time-record
  (raw:make-time type nanosecond second)
  time?
  (type time-type set-time-type!)
  (nanosecond time-nanosecond set-time-nanosecond!)
  (second time-second set-time-second!))

(define (make-time type nanosecond second)
  (let* ((seconds-adjustment (div nanosecond tm:nano))
         (nsec               (mod nanosecond tm:nano))
         (seconds (+ second seconds-adjustment)))
    (raw:make-time type nsec seconds)))

;; thanks, Martin Gasbichler ...

(define (copy-time time)
  (raw:make-time (time-type time)
                 (time-nanosecond time)
                 (time-second time)))


;;; current-time

;;; BEGIN PLATFORM DEPENDENT

;; Time getters.

(define (tm:get-time-of-day)
  (let-values (((secs usecs) (larceny/current-time)))
    (values secs (quotient usecs 1000))))

(define (tm:current-time-utc)
  (receive (seconds ms) (tm:get-time-of-day)
           (make-time  time-utc (* ms 10000) seconds )))

(define (tm:current-time-tai)
  (receive (seconds ms) (tm:get-time-of-day)
           (make-time time-tai
                      (* ms 10000)
                      (+ seconds (tm:leap-second-delta seconds))
                      )))

(define (tm:current-time-ms-time time-type proc)
  (let ((current-ms (proc)))
    (make-time time-type 
               (* (remainder current-ms 1000) 10000)
               (quotient current-ms 10000)
               )))

(define tm:local-tz-offset
  (lambda ()
    (let-values (((secs usecs) (larceny/current-time)))
      (larceny/timezone-offset secs))))

;; -- we define it to be the same as tai.
;;    a different implemation of current-time-montonic
;;    will require rewriting all of the time-monotonic converters,
;;    of course.

(define (tm:current-time-monotonic)
  (receive (seconds ms) (tm:get-time-of-day)
           (make-time time-monotonic
                      (* ms 10000)
                      (+ seconds (tm:leap-second-delta seconds))
                      )))

(define (tm:current-time-thread)
  (tm:current-time-ms-time time-process current-process-milliseconds))

(define (tm:current-time-process)
  (tm:current-time-ms-time time-process current-process-milliseconds))

(define (tm:current-time-gc)
  (tm:current-time-ms-time time-gc current-gc-milliseconds))

;; -- time resolution
;; this is the resolution of the clock in nanoseconds.
;; this will be implementation specific.

(define (time-resolution . clock-type)
  (let ((clock-type (:optional-19 clock-type time-utc)))
    (cond
      ((eq? clock-type time-tai) 10000)
      ((eq? clock-type time-utc) 10000)
      ((eq? clock-type time-monotonic) 10000)
      ((eq? clock-type time-thread) 10000)
      ((eq? clock-type time-process) 10000)
      ((eq? clock-type time-gc) 10000)
      (else (tm:time-error 'time-resolution 'invalid-clock-type clock-type)))))

;;; END PLATFORM DEPENDENT

(define (current-time . clock-type)
  (let ( (clock-type (:optional-19 clock-type time-utc)) )
    (cond
      ((eq? clock-type time-tai) (tm:current-time-tai))
      ((eq? clock-type time-utc) (tm:current-time-utc))
      ((eq? clock-type time-monotonic) (tm:current-time-monotonic))
      ((eq? clock-type time-thread) (tm:current-time-thread))
      ((eq? clock-type time-process) (tm:current-time-process))
      ((eq? clock-type time-gc) (tm:current-time-gc))
      (else (tm:time-error 'current-time 'invalid-clock-type clock-type)))))


;; -- time comparisons

(define (tm:time-compare-check time1 time2 caller)
  (if (or (not (and (time? time1) (time? time2)))
          (not (eq? (time-type time1) (time-type time2))))
      (tm:time-error caller 'incompatible-time-types #f)
      #t))

(define (time=? time1 time2)
  (tm:time-compare-check time1 time2 'time=?)
  (and (= (time-second time1) (time-second time2))
       (= (time-nanosecond time1) (time-nanosecond time2))))

(define (time>? time1 time2)
  (tm:time-compare-check time1 time2 'time>?)
  (or (> (time-second time1) (time-second time2))
      (and (= (time-second time1) (time-second time2))
           (> (time-nanosecond time1) (time-nanosecond time2)))))

(define (time<? time1 time2)
  (tm:time-compare-check time1 time2 'time<?)
  (or (< (time-second time1) (time-second time2))
      (and (= (time-second time1) (time-second time2))
           (< (time-nanosecond time1) (time-nanosecond time2)))))

(define (time>=? time1 time2)
  (tm:time-compare-check time1 time2 'time>=?)
  (or (>= (time-second time1) (time-second time2))
      (and (= (time-second time1) (time-second time2))
           (>= (time-nanosecond time1) (time-nanosecond time2)))))

(define (time<=? time1 time2)
  (tm:time-compare-check time1 time2 'time<=?)
  (or (<= (time-second time1) (time-second time2))
      (and (= (time-second time1) (time-second time2))
           (<= (time-nanosecond time1) (time-nanosecond time2)))))

;; -- time arithmetic

(define (tm:time->nanoseconds time)
  (define (sign1 n)
    (if (negative? n) -1 1))
  (+ (* (time-second time) tm:nano)
      (time-nanosecond time)))

(define (tm:nanoseconds->time time-type nanoseconds)
  (make-time time-type
             (remainder nanoseconds tm:nano)
             (quotient nanoseconds tm:nano)))

(define (tm:nanoseconds->values nanoseconds)
  (values (abs (remainder nanoseconds tm:nano))
          (quotient nanoseconds tm:nano)))

(define (tm:time-difference time1 time2 time3)
  (if (or (not (and (time? time1) (time? time2)))
          (not (eq? (time-type time1) (time-type time2))))
      (tm:time-error 'time-difference 'incompatible-time-types #f))
  (set-time-type! time3 time-duration)
  (if (time=? time1 time2)
      (begin
        (set-time-second! time3 0)
        (set-time-nanosecond! time3 0))
      (receive 
       (nanos secs)
       (tm:nanoseconds->values (- (tm:time->nanoseconds time1)
                                  (tm:time->nanoseconds time2)))
       (set-time-second! time3 secs)
       (set-time-nanosecond! time3 nanos)))
  time3)

(define (time-difference time1 time2)
  (tm:time-difference time1 time2 (raw:make-time #f #f #f)))

(define (time-difference! time1 time2)
  (tm:time-difference time1 time2 time1))

(define (tm:add-duration time1 duration time3)
  (if (not (and (time? time1) (time? duration)))
      (tm:time-error 'add-duration 'incompatible-time-types #f))
  (if (not (eq? (time-type duration) time-duration))
      (tm:time-error 'add-duration 'not-duration duration)
      (let ( (sec-plus (+ (time-second time1) (time-second duration)))
             (nsec-plus (+ (time-nanosecond time1) (time-nanosecond duration))) )
        (let ((r (remainder nsec-plus tm:nano))
              (q (quotient nsec-plus tm:nano)))
          ; (set-time-type! time3 (time-type time1))
          (if (negative? r)
              (begin
                (set-time-second! time3 (+ sec-plus q -1))
                (set-time-nanosecond! time3 (+ tm:nano r)))
              (begin
                (set-time-second! time3 (+ sec-plus q))
                (set-time-nanosecond! time3 r)))
          time3))))

(define (add-duration time1 duration)
  (tm:add-duration time1 duration (raw:make-time (time-type time1) #f #f)))

(define (add-duration! time1 duration)
  (tm:add-duration time1 duration time1))

(define (tm:subtract-duration time1 duration time3)
  (if (not (and (time? time1) (time? duration)))
      (tm:time-error 'add-duration 'incompatible-time-types #f))
  (if (not (eq? (time-type duration) time-duration))
      (tm:time-error 'tm:subtract-duration 'not-duration duration)
      (let ( (sec-minus  (- (time-second time1) (time-second duration)))
             (nsec-minus (- (time-nanosecond time1) (time-nanosecond duration))) )
        (let ((r (remainder nsec-minus tm:nano))
              (q (quotient nsec-minus tm:nano)))
          (if (negative? r)
              (begin
                (set-time-second! time3 (- sec-minus q 1))
                (set-time-nanosecond! time3 (+ tm:nano r)))
              (begin
                (set-time-second! time3 (- sec-minus q))
                (set-time-nanosecond! time3 r)))
          time3))))

(define (subtract-duration time1 duration)
  (tm:subtract-duration time1 duration (raw:make-time (time-type time1) #f #f)))

(define (subtract-duration! time1 duration)
  (tm:subtract-duration time1 duration time1))


;; -- converters between types.

(define (tm:time-tai->time-utc! time-in time-out caller)
  (if (not (eq? (time-type time-in) time-tai))
      (tm:time-error caller 'incompatible-time-types time-in))
  (set-time-type! time-out time-utc)
  (set-time-nanosecond! time-out (time-nanosecond time-in))
  (set-time-second!     time-out (- (time-second time-in)
                                    (tm:leap-second-neg-delta 
                                     (time-second time-in))))
  time-out)

(define (time-tai->time-utc time-in)
  (tm:time-tai->time-utc! time-in (raw:make-time #f #f #f) 'time-tai->time-utc))


(define (time-tai->time-utc! time-in)
  (tm:time-tai->time-utc! time-in time-in 'time-tai->time-utc!))


(define (tm:time-utc->time-tai! time-in time-out caller)
  (if (not (eq? (time-type time-in) time-utc))
      (tm:time-error caller 'incompatible-time-types time-in))
  (set-time-type! time-out time-tai)
  (set-time-nanosecond! time-out (time-nanosecond time-in))
  (set-time-second!     time-out (+ (time-second time-in)
                                    (tm:leap-second-delta 
                                     (time-second time-in))))
  time-out)


(define (time-utc->time-tai time-in)
  (tm:time-utc->time-tai! time-in (raw:make-time #f #f #f) 'time-utc->time-tai))

(define (time-utc->time-tai! time-in)
  (tm:time-utc->time-tai! time-in time-in 'time-utc->time-tai!))

;; -- these depend on time-monotonic having the same definition as time-tai!
(define (time-monotonic->time-utc time-in)
  (if (not (eq? (time-type time-in) time-monotonic))
      (tm:time-error 'time-monotoinc->time-utc 'incompatible-time-types time-in))
  (let ((ntime (copy-time time-in)))
    (set-time-type! ntime time-tai)
    (tm:time-tai->time-utc! ntime ntime 'time-monotonic->time-utc)))

(define (time-monotonic->time-utc! time-in)
  (if (not (eq? (time-type time-in) time-monotonic))
      (tm:time-error 'time-monotonic->time-utc! 'incompatible-time-types time-in))
  (set-time-type! time-in time-tai)
  (tm:time-tai->time-utc! time-in time-in 'time-monotonic->time-utc))

(define (time-monotonic->time-tai time-in)
  (if (not (eq? (time-type time-in) time-monotonic))
      (tm:time-error 'time-monotonic->time-tai 'incompatible-time-types time-in))
  (let ((ntime (copy-time time-in)))
    (set-time-type! ntime time-tai)
    ntime))

(define (time-monotonic->time-tai! time-in)
  (if (not (eq? (time-type time-in) time-monotonic))
      (tm:time-error 'time-monotonic->time-tai! 'incompatible-time-types time-in))
  (set-time-type! time-in time-tai)
  time-in)

(define (time-utc->time-monotonic time-in)
  (if (not (eq? (time-type time-in) time-utc))
      (tm:time-error 'time-utc->time-monotonic 'incompatible-time-types time-in))
  (let ((ntime (tm:time-utc->time-tai! time-in (raw:make-time #f #f #f)
                                       'time-utc->time-monotonic)))
    (set-time-type! ntime time-monotonic)
    ntime))


(define (time-utc->time-monotonic! time-in)
  (if (not (eq? (time-type time-in) time-utc))
      (tm:time-error 'time-utc->time-montonic! 'incompatible-time-types time-in))
  (let ((ntime (tm:time-utc->time-tai! time-in time-in
                                       'time-utc->time-monotonic!)))
    (set-time-type! ntime time-monotonic)
    ntime))


(define (time-tai->time-monotonic time-in)
  (if (not (eq? (time-type time-in) time-tai))
      (tm:time-error 'time-tai->time-monotonic 'incompatible-time-types time-in))
  (let ((ntime (copy-time time-in)))
    (set-time-type! ntime time-monotonic)
    ntime))

(define (time-tai->time-monotonic! time-in)
  (if (not (eq? (time-type time-in) time-tai))
      (tm:time-error 'time-tai->time-monotonic!  'incompatible-time-types time-in))
  (set-time-type! time-in time-monotonic)
  time-in)


;; -- date structures

;(define-struct date 
;  (nanosecond second minute hour day month year zone-offset)
;  (make-inspector))

(define-record-type date
  (make-date nanosecond second minute hour day month year zone-offset)
  date?
  (nanosecond date-nanosecond set-date-nanosecond!)
  (second date-second set-date-second!)
  (minute date-minute set-date-minute!)
  (hour date-hour set-date-hour!)
  (day date-day set-date-day!)
  (month date-month set-date-month!)
  (year date-year set-date-year!)
  (zone-offset date-zone-offset set-date-zone-offset!))

;; redefine setters

(define tm:set-date-nanosecond! set-date-nanosecond!)
(define tm:set-date-second! set-date-second!)
(define tm:set-date-minute! set-date-minute!)
(define tm:set-date-hour! set-date-hour!)
(define tm:set-date-day! set-date-day!)
(define tm:set-date-month! set-date-month!)
(define tm:set-date-year! set-date-year!)
(define tm:set-date-zone-offset! set-date-zone-offset!)

#|
(define (set-date-second! date val)
  (tm:time-error 'set-date-second! 'dates-are-immutable date))

(define (set-date-minute! date val)
  (tm:time-error 'set-date-minute! 'dates-are-immutable date))

(define (set-date-day! date val)
  (tm:time-error 'set-date-day! 'dates-are-immutable date))

(define (set-date-month! date val)
  (tm:time-error 'set-date-month! 'dates-are-immutable date))

(define (set-date-year! date val)
  (tm:time-error 'set-date-year! 'dates-are-immutable date))

(define (set-date-zone-offset! date val)
  (tm:time-error 'set-date-zone-offset! 'dates-are-immutable date))
|#

;; gives the julian day which starts at noon.
(define (tm:encode-julian-day-number day month year)
  (let* ((a (quotient (- 14 month) 12))
         (y (- (- (+ year 4800) a) (if (negative? year) -1 0)))
         (m (- (+ month (* 12 a)) 3)))
    (+ day
       (quotient (+ (* 153 m) 2) 5)
       (* 365 y)
       (quotient y 4)
       (- (quotient y 100))
       (quotient y 400)
       -32045)))

(define (tm:char-pos char str index len)
  (cond
   ((>= index len) #f)
   ((char=? (string-ref str index) char)
    index)
   (else
    (tm:char-pos char str (+ index 1) len))))
  

(define (tm:fractional-part r)
  (if (integer? r) "0"
      (let ((str (number->string (+ 1.0 r))))
	(let ((ppos (tm:char-pos #\. str 0 (string-length str))))
	  (substring str  (+ ppos 1) (string-length str))))))


;; gives the seconds/date/month/year 
(define (tm:decode-julian-day-number jdn)
  (let* ((days (truncate jdn))
         (a (+ days 32044))
         (b (quotient (+ (* 4 a) 3) 146097))
         (c (- a (quotient (* 146097 b) 4)))
         (d (quotient (+ (* 4 c) 3) 1461))
         (e (- c (quotient (* 1461 d) 4)))
         (m (quotient (+ (* 5 e) 2) 153))
         (y (+ (* 100 b) d -4800 (quotient m 10))))
    (values ; seconds date month year
     (* (- jdn days) tm:sid)
     (+ e (- (quotient (+ (* 153 m) 2) 5)) 1)
     (+ m 3 (* -12 (quotient m 10)))
     (if (>= 0 y) (- y 1) y))
    ))


;; special thing -- ignores nanos
(define (tm:time->julian-day-number seconds tz-offset)
  (+ (/ (+ seconds
           tz-offset
           tm:sihd)
        tm:sid)
     tm:tai-epoch-in-jd))

(define (tm:find proc l)
  (if (null? l)
      #f
      (if (proc (car l))
          #t
          (tm:find proc (cdr l)))))

(define (tm:tai-before-leap-second? second)
  (tm:find (lambda (x)
             (= second (- (+ (car x) (cdr x)) 1)))
           tm:leap-second-table))

(define (tm:time->date time tz-offset ttype)
  (if (not (eq? (time-type time) ttype))
      (tm:time-error 'time->date 'incompatible-time-types  time))
  (let* ( (offset (:optional-19 tz-offset (tm:local-tz-offset))) )
    (receive (secs date month year)
             (tm:decode-julian-day-number
              (tm:time->julian-day-number (time-second time) offset))
             (let* ( (hours    (quotient secs (* 60 60)))
                     (rem      (remainder secs (* 60 60)))
                     (minutes  (quotient rem 60))
                     (seconds  (remainder rem 60)) )
               (make-date (time-nanosecond time)
                          seconds
                          minutes
                          hours
                          date
                          month
                          year
                          offset)))))

(define (time-tai->date time . tz-offset)
  (if (tm:tai-before-leap-second? (time-second time))
      ;; if it's *right* before the leap, we need to pretend to subtract a second ...
      (let ((d (tm:time->date (subtract-duration! (time-tai->time-utc time) (make-time time-duration 0 1)) tz-offset time-utc)))
        (tm:set-date-second! d 60)
        d)
      (tm:time->date (time-tai->time-utc time) tz-offset time-utc)))

(define (time-utc->date time . tz-offset)
  (tm:time->date time tz-offset time-utc))

;; again, time-monotonic is the same as time tai
(define (time-monotonic->date time . tz-offset)
  (tm:time->date time tz-offset time-monotonic))

(define (date->time-utc date)
  (let ( (nanosecond (date-nanosecond date))
         (second (date-second date))
         (minute (date-minute date))
         (hour (date-hour date))
         (day (date-day date))
         (month (date-month date))
         (year (date-year date))
         (offset (date-zone-offset date)) )
    (let ( (jdays (- (tm:encode-julian-day-number day month year)
                     tm:tai-epoch-in-jd)) )
      (make-time 
       time-utc
       nanosecond
       (+ (* (- jdays 1/2) 24 60 60)
          (* hour 60 60)
          (* minute 60)
          second
          (- offset))
       ))))

(define (date->time-tai d)
  (if (= (date-second d) 60)
      (subtract-duration! (time-utc->time-tai! (date->time-utc d)) (make-time time-duration 0 1))
      (time-utc->time-tai! (date->time-utc d))))

(define (date->time-monotonic date)
  (time-utc->time-monotonic! (date->time-utc date)))


(define (tm:leap-year? year)
  (or (= (modulo year 400) 0)
      (and (= (modulo year 4) 0) (not (= (modulo year 100) 0)))))

(define (leap-year? date)
  (tm:leap-year? (date-year date)))

;; tm:year-day fixed: adding wrong number of days.
(define  tm:month-assoc '((0 . 0) (1 . 31)  (2 . 59)   (3 . 90)   (4 . 120) 
                          (5 . 151) (6 . 181)  (7 . 212)  (8 . 243)
                          (9 . 273) (10 . 304) (11 . 334)))

(define (tm:year-day day month year)
  (let ((days-pr (assoc (- month 1) tm:month-assoc)))
    (if (not days-pr)
        (tm:time-error 'date-year-day 'invalid-month-specification month))
    (if (and (tm:leap-year? year) (> month 2))
        (+ day (cdr days-pr) 1)
        (+ day (cdr days-pr)))))

(define (date-year-day date)
  (tm:year-day (date-day date) (date-month date) (date-year date)))

;; from calendar faq 
(define (tm:week-day day month year)
  (let* ((a (quotient (- 14 month) 12))
         (y (- year a))
         (m (+ month (* 12 a) -2)))
    (modulo (+ day y (quotient y 4) (- (quotient y 100))
               (quotient y 400) (quotient (* 31 m) 12))
            7)))

(define (date-week-day date)
  (tm:week-day (date-day date) (date-month date) (date-year date)))

(define (tm:days-before-first-week date day-of-week-starting-week)
  (let* ( (first-day (make-date 0 0 0 0
                                1
                                1
                                (date-year date)
                                #f))
          (fdweek-day (date-week-day first-day))  )
    (modulo (- day-of-week-starting-week fdweek-day)
            7)))

(define (date-week-number date day-of-week-starting-week)
  (quotient (- (date-year-day date)
               (tm:days-before-first-week  date day-of-week-starting-week))
            7))

(define (current-date . tz-offset) 
  (time-utc->date (current-time time-utc)
                  (:optional-19 tz-offset (tm:local-tz-offset))))

;; given a 'two digit' number, find the year within 50 years +/-
(define (tm:natural-year n)
  (let* ( (current-year (date-year (current-date)))
          (current-century (* (quotient current-year 100) 100)) )
    (cond
      ((>= n 100) n)
      ((<  n 0) n)
      ((<=  (- (+ current-century n) current-year) 50)
       (+ current-century n))
      (else
       (+ (- current-century 100) n)))))

(define (date->julian-day date)
  (let ( (nanosecond (date-nanosecond date))
         (second (date-second date))
         (minute (date-minute date))
         (hour (date-hour date))
         (day (date-day date))
         (month (date-month date))
         (year (date-year date))
         (offset (date-zone-offset date)) )
    (+ (tm:encode-julian-day-number day month year)
       (- 1/2)
       (+ (/ (/ (+ (* hour 60 60)
                   (* minute 60) second (/ nanosecond tm:nano)) tm:sid)
             (- offset))))))

(define (date->modified-julian-day date)
  (- (date->julian-day date)
     4800001/2))


(define (time-utc->julian-day time)
  (if (not (eq? (time-type time) time-utc))
      (tm:time-error 'time-utc->julian-day 'incompatible-time-types  time))
  (+ (/ (+ (time-second time) (/ (time-nanosecond time) tm:nano))
        tm:sid)
     tm:tai-epoch-in-jd))

(define (time-utc->modified-julian-day time)
  (- (time-utc->julian-day time)
     4800001/2))

(define (time-tai->julian-day time)
  (if (not (eq? (time-type time) time-tai))
      (tm:time-error 'time-tai->julian-day 'incompatible-time-types  time))
  (+ (/ (+ (- (time-second time) 
              (tm:leap-second-delta (time-second time)))
           (/ (time-nanosecond time) tm:nano))
        tm:sid)
     tm:tai-epoch-in-jd))

(define (time-tai->modified-julian-day time)
  (- (time-tai->julian-day time)
     4800001/2))

;; this is the same as time-tai->julian-day
(define (time-monotonic->julian-day time)
  (if (not (eq? (time-type time) time-monotonic))
      (tm:time-error 'time-monotonic->julian-day 'incompatible-time-types  time))
  (+ (/ (+ (- (time-second time) 
              (tm:leap-second-delta (time-second time)))
           (/ (time-nanosecond time) tm:nano))
        tm:sid)
     tm:tai-epoch-in-jd))


(define (time-monotonic->modified-julian-day time)
  (- (time-monotonic->julian-day time)
     4800001/2))


(define (julian-day->time-utc jdn)
  (let ( (nanosecs (* tm:nano tm:sid (- jdn tm:tai-epoch-in-jd))) )
    (make-time time-utc
               (remainder nanosecs tm:nano)
               (floor (/ nanosecs tm:nano)))))

(define (julian-day->time-tai jdn)
  (time-utc->time-tai! (julian-day->time-utc jdn)))

(define (julian-day->time-monotonic jdn)
  (time-utc->time-monotonic! (julian-day->time-utc jdn)))

(define (julian-day->date jdn . tz-offset)
  (let ((offset (:optional-19 tz-offset (tm:local-tz-offset))))
    (time-utc->date (julian-day->time-utc jdn) offset)))

(define (modified-julian-day->date jdn . tz-offset)
  (let ((offset (:optional-19 tz-offset (tm:local-tz-offset))))
    (julian-day->date (+ jdn 4800001/2) offset)))

(define (modified-julian-day->time-utc jdn)
  (julian-day->time-utc (+ jdn 4800001/2)))

(define (modified-julian-day->time-tai jdn)
  (julian-day->time-tai (+ jdn 4800001/2)))

(define (modified-julian-day->time-monotonic jdn)
  (julian-day->time-monotonic (+ jdn 4800001/2)))

(define (current-julian-day)
  (time-utc->julian-day (current-time time-utc)))

(define (current-modified-julian-day)
  (time-utc->modified-julian-day (current-time time-utc)))

;; returns a string rep. of number N, of minimum LENGTH,
;; padded with character PAD-WITH. If PAD-WITH if #f, 
;; no padding is done, and it's as if number->string was used.
;; if string is longer than LENGTH, it's as if number->string was used.

(define (tm:padding n pad-with length)
  (let* ( (str (number->string n))
          (str-len (string-length str)) )
    (if (or (> str-len length)
            (not pad-with))
        str
        (let* ( (new-str (make-string length pad-with))
                (new-str-offset (- (string-length new-str)
                                   str-len)) )
          (do ((i 0 (+ i 1)))
            ((>= i (string-length str)))
            (string-set! new-str (+ new-str-offset i) 
                         (string-ref str i)))
          new-str))))

(define (tm:last-n-digits i n)
  (abs (remainder i (expt 10 n))))

(define (tm:locale-abbr-weekday n) 
  (vector-ref tm:locale-abbr-weekday-vector n))

(define (tm:locale-long-weekday n)
  (vector-ref tm:locale-long-weekday-vector n))

(define (tm:locale-abbr-month n)
  (vector-ref tm:locale-abbr-month-vector n))

(define (tm:locale-long-month n)
  (vector-ref tm:locale-long-month-vector n))

(define (tm:vector-find needle haystack comparator)
  (let ((len (vector-length haystack)))
    (define (tm:vector-find-int index)
      (cond
        ((>= index len) #f)
        ((comparator needle (vector-ref haystack index)) index)
        (else (tm:vector-find-int (+ index 1)))))
    (tm:vector-find-int 0)))

(define (tm:locale-abbr-weekday->index string)
  (tm:vector-find string tm:locale-abbr-weekday-vector string=?))

(define (tm:locale-long-weekday->index string)
  (tm:vector-find string tm:locale-long-weekday-vector string=?))

(define (tm:locale-abbr-month->index string)
  (tm:vector-find string tm:locale-abbr-month-vector string=?))

(define (tm:locale-long-month->index string)
  (tm:vector-find string tm:locale-long-month-vector string=?))



;; do nothing. 
;; Your implementation might want to do something...
;; 
(define (tm:locale-print-time-zone date port)
  (values))

;; Again, locale specific.
(define (tm:locale-am/pm hr)
  (if (> hr 11) tm:locale-pm tm:locale-am))

(define (tm:tz-printer offset port)
  (cond
    ((= offset 0) (display "Z" port))
    ((negative? offset) (display "-" port))
    (else (display "+" port)))
  (if (not (= offset 0))
      (let ( (hours   (abs (quotient offset (* 60 60))))
             (minutes (abs (quotient (remainder offset (* 60 60)) 60))) )
        (display (tm:padding hours #\0 2) port)
        (display (tm:padding minutes #\0 2) port))))

;; A table of output formatting directives.
;; the first time is the format char.
;; the second is a procedure that takes the date, a padding character
;; (which might be #f), and the output port.
;;
(define tm:directives 
  (list
   (cons #\~ (lambda (date pad-with port) (display #\~ port)))
   
   (cons #\a (lambda (date pad-with port)
               (display (tm:locale-abbr-weekday (date-week-day date))
                        port)))
   (cons #\A (lambda (date pad-with port)
               (display (tm:locale-long-weekday (date-week-day date))
                        port)))
   (cons #\b (lambda (date pad-with port)
               (display (tm:locale-abbr-month (date-month date))
                        port)))
   (cons #\B (lambda (date pad-with port)
               (display (tm:locale-long-month (date-month date))
                        port)))
   (cons #\c (lambda (date pad-with port)
               (display (date->string date tm:locale-date-time-format) port)))
   (cons #\d (lambda (date pad-with port)
               (display (tm:padding (date-day date)
                                    #\0 2)
                        port)))
   (cons #\D (lambda (date pad-with port)
               (display (date->string date "~m/~d/~y") port)))
   (cons #\e (lambda (date pad-with port)
               (display (tm:padding (date-day date)
                                    #\space 2)
                        port)))
   (cons #\f (lambda (date pad-with port)
	       (if (> (date-nanosecond date)
		      tm:nano)
		   (display (tm:padding (+ (date-second date) 1)
					pad-with 2)
			    port)
		   (display (tm:padding (date-second date)
					pad-with 2)
			    port))
	       (let* ((ns (tm:fractional-part (/ 
					       (date-nanosecond date)
					       tm:nano 1.0))))
                 (display tm:locale-number-separator port)
                 (display ns port))))
   (cons #\h (lambda (date pad-with port)
               (display (date->string date "~b") port)))
   (cons #\H (lambda (date pad-with port)
               (display (tm:padding (date-hour date)
                                    pad-with 2)
                        port)))
   (cons #\I (lambda (date pad-with port)
               (let ((hr (date-hour date)))
                 (if (> hr 12)
                     (display (tm:padding (- hr 12)
                                          pad-with 2)
                              port)
                     (display (tm:padding hr
                                          pad-with 2)
                              port)))))
   (cons #\j (lambda (date pad-with port)
               (display (tm:padding (date-year-day date)
                                    pad-with 3)
                        port)))
   (cons #\k (lambda (date pad-with port)
	       (display (tm:padding (date-hour date)
				    #\space 2)
                        port)))
   (cons #\l (lambda (date pad-with port)
               (let ((hr (if (> (date-hour date) 12)
                             (- (date-hour date) 12) (date-hour date))))
                 (display (tm:padding hr  #\space 2)
                          port))))
   (cons #\m (lambda (date pad-with port)
               (display (tm:padding (date-month date)
                                    pad-with 2)
                        port)))
   (cons #\M (lambda (date pad-with port)
               (display (tm:padding (date-minute date)
                                    pad-with 2)
                        port)))
   (cons #\n (lambda (date pad-with port)
               (newline port)))
   (cons #\N (lambda (date pad-with port)
	       (display (tm:padding (date-nanosecond date)
				    pad-with 9)
			port)))
   (cons #\p (lambda (date pad-with port)
               (display (tm:locale-am/pm (date-hour date)) port)))
   (cons #\r (lambda (date pad-with port)
               (display (date->string date "~I:~M:~S ~p") port)))
   (cons #\s (lambda (date pad-with port)
               (display (time-second (date->time-utc date)) port)))
   (cons #\S (lambda (date pad-with port)
               (if (> (date-nanosecond date)
                      tm:nano)
                   (display (tm:padding (+ (date-second date) 1)
                                        pad-with 2)
                            port)
                   (display (tm:padding (date-second date)
                                        pad-with 2)
                            port))))
   (cons #\t (lambda (date pad-with port)
               (display (integer->char 9) port)))
   (cons #\T (lambda (date pad-with port)
               (display (date->string date "~H:~M:~S") port)))

   ;; FIXME:  Something is wrong with the SRFI 19 specification of
   ;; the ~U, ~V, ~W, and ~x format strings.
   ;;
   ;; Comparing the specification with the reference implementation,
   ;; it appears that the specification of ~x is completely wrong.
   ;;
   ;; The specifications of ~V and ~W are exactly the same.
   ;; Furthermore both ~V and ~W are specified to return a result
   ;; in the 01..52 range, which doesn't make sense.
   ;;
   ;; For the time being, Larceny will assume that both the
   ;; specification and implementation of ~U are correct,
   ;; so it returns a zero-origin index (counting Sunday as
   ;; the beginning of a week).  Larceny will assume that
   ;; the reference implementation of ~W is correct, and
   ;; that its specification is correct except its result
   ;; will be in 00..53 instead of 01..52.
   ;;
   ;; Larceny will assume that both the specification and the
   ;; implementation of ~V are incorrect, but we don't know
   ;; how to fix either so we won't try.

   (cons #\U (lambda (date pad-with port)
               (if (> (tm:days-before-first-week date 0) 0)
                   (display (tm:padding (+ (date-week-number date 0) 1)
                                        #\0 2) port)
                   (display (tm:padding (date-week-number date 0)
                                        #\0 2) port))))
   (cons #\V (lambda (date pad-with port)
               (display (tm:padding (date-week-number date 1)
                                    #\0 2) port)))
   (cons #\w (lambda (date pad-with port)
               (display (date-week-day date) port)))
   (cons #\x (lambda (date pad-with port)
               (display (date->string date tm:locale-short-date-format) port)))
   (cons #\X (lambda (date pad-with port)
               (display (date->string date tm:locale-time-format) port)))
   (cons #\W (lambda (date pad-with port)
               (if (> (tm:days-before-first-week date 1) 0)
                   (display (tm:padding (+ (date-week-number date 1) 1)
                                        #\0 2) port)
                   (display (tm:padding (date-week-number date 1)
                                        #\0 2) port))))
   (cons #\y (lambda (date pad-with port)
               (display (tm:padding (tm:last-n-digits 
                                     (date-year date) 2)
                                    pad-with
                                    2)
                        port)))
   (cons #\Y (lambda (date pad-with port)
               (display (date-year date) port)))
   (cons #\z (lambda (date pad-with port)
               (tm:tz-printer (date-zone-offset date) port)))
   (cons #\Z (lambda (date pad-with port)
               (tm:locale-print-time-zone date port)))
   (cons #\1 (lambda (date pad-with port)
               (display (date->string date "~Y-~m-~d") port)))
   (cons #\2 (lambda (date pad-with port)
               (display (date->string date "~H:~M:~S~z") port)))
   (cons #\3 (lambda (date pad-with port)
               (display (date->string date "~H:~M:~S") port)))
   (cons #\4 (lambda (date pad-with port)
               (display (date->string date "~Y-~m-~dT~H:~M:~S~z") port)))
   (cons #\5 (lambda (date pad-with port)
               (display (date->string date "~Y-~m-~dT~H:~M:~S") port)))
   ))


(define (tm:get-formatter char)
  (let ( (associated (assoc char tm:directives)) )
    (if associated (cdr associated) #f)))

(define (tm:date-printer date index format-string str-len port)
  (if (>= index str-len)
      (values)
      (let ( (current-char (string-ref format-string index)) )
        (if (not (char=? current-char #\~))
            (begin
              (display current-char port)
              (tm:date-printer date (+ index 1) format-string str-len port))

            (if (= (+ index 1) str-len) ; bad format string.
                (tm:time-error 'tm:date-printer 'bad-date-format-string 
                               format-string)
                (let ( (pad-char? (string-ref format-string (+ index 1))) )
                  (cond
                    ((char=? pad-char? #\-)
                     (if (= (+ index 2) str-len) ; bad format string.
                         (tm:time-error 'tm:date-printer 'bad-date-format-string 
                                        format-string)
                         (let ( (formatter (tm:get-formatter 
                                            (string-ref format-string
                                                        (+ index 2)))) )
                           (if (not formatter)
                               (tm:time-error 'tm:date-printer 'bad-date-format-string 
                                              format-string)
                               (begin
                                 (formatter date #f port)
                                 (tm:date-printer date (+ index 3)
                                                  format-string str-len port))))))
                    
                    ((char=? pad-char? #\_)
                     (if (= (+ index 2) str-len) ; bad format string.
                         (tm:time-error 'tm:date-printer 'bad-date-format-string 
                                        format-string)
                         (let ( (formatter (tm:get-formatter 
                                            (string-ref format-string
                                                        (+ index 2)))) )
                           (if (not formatter)
                               (tm:time-error 'tm:date-printer 'bad-date-format-string 
                                              format-string)
                               (begin
                                 (formatter date #\space port)
                                 (tm:date-printer date (+ index 3)
                                                  format-string str-len port))))))
                    (else
                     (let ( (formatter (tm:get-formatter 
                                        (string-ref format-string
                                                    (+ index 1)))) )
                       (if (not formatter)
                           (tm:time-error 'tm:date-printer 'bad-date-format-string 
                                          format-string)
                           (begin
                             (formatter date #\0 port)
                             (tm:date-printer date (+ index 2)
                                              format-string str-len port))))))))))))


(define (date->string date .  format-string)
  (let ( (str-port (open-output-string))
         (fmt-str (:optional-19 format-string "~c")) )
    (tm:date-printer date 0 fmt-str (string-length fmt-str) str-port)
    (get-output-string str-port)))

(define (tm:char->int ch)
  (cond
    ((char=? ch #\0) 0)
    ((char=? ch #\1) 1)
    ((char=? ch #\2) 2)
    ((char=? ch #\3) 3)
    ((char=? ch #\4) 4)
    ((char=? ch #\5) 5)
    ((char=? ch #\6) 6)
    ((char=? ch #\7) 7)
    ((char=? ch #\8) 8)
    ((char=? ch #\9) 9)
    (else (tm:time-error 'string->date 'bad-date-template-string
                         (list "Non-integer character" ch )))))

;; read an integer upto n characters long on port; upto -> #f if any length
(define (tm:integer-reader upto port)
  (define (accum-int port accum nchars)
    (let ((ch (peek-char port)))
      (if (or (eof-object? ch)
              (not (char-numeric? ch))
              (and upto (>= nchars  upto )))
          accum
          (accum-int port (+ (* accum 10) (tm:char->int (read-char
                                                         port))) (+
                                                                  nchars 1)))))
  (accum-int port 0 0))

(define (tm:make-integer-reader upto)
  (lambda (port)
    (tm:integer-reader upto port)))

;; read *exactly* n characters and convert to integer; could be padded
(define (tm:integer-reader-exact n port)
  (let ( (padding-ok #t) )
    (define (accum-int port accum nchars)
      (let ((ch (peek-char port)))
        (cond
          ((>= nchars n) accum)
          ((eof-object? ch) 
           (tm:time-error 'string->date 'bad-date-template-string 
                          "Premature ending to integer read."))
          ((char-numeric? ch)
           (set! padding-ok #f)
           (accum-int port (+ (* accum 10) (tm:char->int (read-char
                                                          port)))
                      (+ nchars 1)))
          (padding-ok
           (read-char port) ; consume padding
           (accum-int port accum (+ nchars 1)))
          (else ; padding where it shouldn't be
           (tm:time-error 'string->date 'bad-date-template-string 
                          "Non-numeric characters in integer read.")))))
    (accum-int port 0 0)))


(define (tm:make-integer-exact-reader n)
  (lambda (port)
    (tm:integer-reader-exact n port)))

(define (tm:zone-reader port) 
  (let ( (offset 0) 
         (positive? #f) )
    (let ( (ch (read-char port)) )
      (if (eof-object? ch)
          (tm:time-error 'string->date 'bad-date-template-string
                         (list "Invalid time zone +/-" ch)))
      (if (or (char=? ch #\Z) (char=? ch #\z))
          0
          (begin
            (cond
              ((char=? ch #\+) (set! positive? #t))
              ((char=? ch #\-) (set! positive? #f))
              (else
               (tm:time-error 'string->date 'bad-date-template-string
                              (list "Invalid time zone +/-" ch))))
            (let ((ch (read-char port)))
              (if (eof-object? ch)
                  (tm:time-error 'string->date 'bad-date-template-string
                                 (list "Invalid time zone number" ch)))
              (set! offset (* (tm:char->int ch)
                              10 60 60)))
            (let ((ch (read-char port)))
              (if (eof-object? ch)
                  (tm:time-error 'string->date 'bad-date-template-string
                                 (list "Invalid time zone number" ch)))
              (set! offset (+ offset (* (tm:char->int ch)
                                        60 60))))
            (let ((ch (read-char port)))
              (if (eof-object? ch)
                  (tm:time-error 'string->date 'bad-date-template-string
                                 (list "Invalid time zone number" ch)))
              (set! offset (+ offset (* (tm:char->int ch)
                                        10 60))))
            (let ((ch (read-char port)))
              (if (eof-object? ch)
                  (tm:time-error 'string->date 'bad-date-template-string
                                 (list "Invalid time zone number" ch)))
              (set! offset (+ offset (* (tm:char->int ch)
                                        60))))
            (if positive? offset (- offset)))))))

;; looking at a char, read the char string, run thru indexer, return index
(define (tm:locale-reader port indexer)
  (let ( (string-port (open-output-string)) )
    (define (read-char-string)
      (let ((ch (peek-char port)))
        (if (char-alphabetic? ch)
            (begin (write-char (read-char port) string-port) 
                   (read-char-string))
            (get-output-string string-port))))
    (let* ( (str (read-char-string)) 
            (index (indexer str)) )
      (if index index (tm:time-error 'string->date
                                     'bad-date-template-string
                                     (list "Invalid string for " indexer))))))

(define (tm:make-locale-reader indexer)
  (lambda (port)
    (tm:locale-reader port indexer)))

(define (tm:make-char-id-reader char)
  (lambda (port)
    (if (char=? char (read-char port))
        char
        (tm:time-error 'string->date
                       'bad-date-template-string
                       "Invalid character match."))))

;; A List of formatted read directives.
;; Each entry is a list.
;; 1. the character directive; 
;; a procedure, which takes a character as input & returns
;; 2. #t as soon as a character on the input port is acceptable
;; for input,
;; 3. a port reader procedure that knows how to read the current port
;; for a value. Its one parameter is the port.
;; 4. a action procedure, that takes the value (from 3.) and some
;; object (here, always the date) and (probably) side-effects it.
;; In some cases (e.g., ~A) the action is to do nothing

(define tm:read-directives 
  (let ( (ireader4 (tm:make-integer-reader 4))
         (ireader2 (tm:make-integer-reader 2))
         (ireaderf (tm:make-integer-reader #f))
         (eireader2 (tm:make-integer-exact-reader 2))
         (eireader4 (tm:make-integer-exact-reader 4))
         (locale-reader-abbr-weekday (tm:make-locale-reader
                                      tm:locale-abbr-weekday->index))
         (locale-reader-long-weekday (tm:make-locale-reader
                                      tm:locale-long-weekday->index))
         (locale-reader-abbr-month   (tm:make-locale-reader
                                      tm:locale-abbr-month->index))
         (locale-reader-long-month   (tm:make-locale-reader
                                      tm:locale-long-month->index))
         (char-fail (lambda (ch) #t))
         (do-nothing (lambda (val object) (values)))
         )
    
    (list
     (list #\~ char-fail (tm:make-char-id-reader #\~) do-nothing)
     (list #\a char-alphabetic? locale-reader-abbr-weekday do-nothing)
     (list #\A char-alphabetic? locale-reader-long-weekday do-nothing)
     (list #\b char-alphabetic? locale-reader-abbr-month
           (lambda (val object)
             (tm:set-date-month! object val)))
     (list #\B char-alphabetic? locale-reader-long-month
           (lambda (val object)
             (tm:set-date-month! object val)))
     (list #\d char-numeric? ireader2 (lambda (val object)
                                        (tm:set-date-day!
                                         object val)))
     (list #\e char-fail eireader2 (lambda (val object)
                                     (tm:set-date-day! object val)))
     (list #\h char-alphabetic? locale-reader-abbr-month
           (lambda (val object)
             (tm:set-date-month! object val)))
     (list #\H char-numeric? ireader2 (lambda (val object)
                                        (tm:set-date-hour! object val)))
     (list #\k char-fail eireader2 (lambda (val object)
                                     (tm:set-date-hour! object val)))
     (list #\m char-numeric? ireader2 (lambda (val object)
                                        (tm:set-date-month! object val)))
     (list #\M char-numeric? ireader2 (lambda (val object)
                                        (tm:set-date-minute!
                                         object val)))
     (list #\S char-numeric? ireader2 (lambda (val object)
                                        (tm:set-date-second! object val)))
     (list #\y char-fail eireader2 
           (lambda (val object)
             (tm:set-date-year! object (tm:natural-year val))))
     (list #\Y char-numeric? ireader4 (lambda (val object)
                                        (tm:set-date-year! object val)))
     (list #\z (lambda (c)
                 (or (char=? c #\Z)
                     (char=? c #\z)
                     (char=? c #\+)
                     (char=? c #\-)))
           tm:zone-reader (lambda (val object)
                            (tm:set-date-zone-offset! object val)))
     )))

(define (tm:string->date date index format-string str-len port template-string)
  (define (skip-until port skipper)
    (let ((ch (peek-char port)))
      (if (eof-object? ch)
          (tm:time-error 'string->date 'bad-date-format-string template-string)
          (if (not (skipper ch))
              (begin (read-char port) (skip-until port skipper))))))
  (if (>= index str-len)
      (begin 
        (values))
      (let ( (current-char (string-ref format-string index)) )
        (if (not (char=? current-char #\~))
            (let ((port-char (read-char port)))
              (if (or (eof-object? port-char)
                      (not (char=? current-char port-char)))
                  (tm:time-error 'string->date 'bad-date-format-string template-string))
              (tm:string->date date (+ index 1) format-string str-len port template-string))
            ;; otherwise, it's an escape, we hope
            (if (> (+ index 1) str-len)
                (tm:time-error 'string->date 'bad-date-format-string template-string)
                (let* ( (format-char (string-ref format-string (+ index 1)))
                        (format-info (assoc format-char tm:read-directives)) )
                  (if (not format-info)
                      (tm:time-error 'string->date 'bad-date-format-string template-string)
                      (begin
                        (let ((skipper (cadr format-info))
                              (reader  (caddr format-info))
                              (actor   (cadddr format-info)))
                          (skip-until port skipper)
                          (let ((val (reader port)))
                            (if (eof-object? val)
                                (tm:time-error 'string->date 'bad-date-format-string template-string)
                                (actor val date)))
                          (tm:string->date date (+ index 2) format-string  str-len port template-string))))))))))

(define (string->date input-string template-string)
  (define (tm:date-ok? date)
    (and (date-nanosecond date)
         (date-second date)
         (date-minute date)
         (date-hour date)
         (date-day date)
         (date-month date)
         (date-year date)
         (date-zone-offset date)))
  (let ( (newdate (make-date 0 0 0 0 #f #f #f (tm:local-tz-offset))) )
    (tm:string->date newdate
                     0
                     template-string
                     (string-length template-string)
                     (open-input-string input-string)
                     template-string)
    (if (tm:date-ok? newdate)
        newdate
        (tm:time-error 'string->date 'bad-date-format-string (list "Incomplete date read. " newdate template-string)))))


)

(library (srfi :19)

  (export time-duration time-monotonic time-process time-tai
          time-thread time-utc
          current-date current-julian-day current-modified-julian-day
          current-time time-resolution
          make-time time? time-type time-nanosecond time-second
          set-time-type! set-time-nanosecond! set-time-second!
          copy-time
          time<=? time<? time=? time>=? time>?
          time-difference time-difference!
          add-duration add-duration!
          subtract-duration subtract-duration!
          make-date date? date-nanosecond date-second
          date-minute date-hour date-day date-month date-year
          date-zone-offset date-year-day date-week-day date-week-number
          date->julian-day date->modified-julian-day
          date->time-monotonic date->time-tai date->time-utc
          julian-day->date julian-day->time-monotonic
          julian-day->time-tai julian-day->time-utc
          modified-julian-day->date modified-julian-day->time-monotonic
          modified-julian-day->time-tai modified-julian-day->time-utc
          time-monotonic->date time-monotonic->julian-day
          time-monotonic->modified-julian-day
          time-monotonic->time-tai  time-monotonic->time-tai!
          time-monotonic->time-utc  time-monotonic->time-utc!
          time-tai->date time-tai->julian-day
          time-tai->modified-julian-day
          time-tai->time-monotonic time-tai->time-monotonic!
          time-tai->time-utc time-tai->time-utc!
          time-utc->date time-utc->julian-day
          time-utc->modified-julian-day
          time-utc->time-monotonic time-utc->time-monotonic!
          time-utc->time-tai time-utc->time-tai!
          date->string string->date)

  (import (srfi :19 time)))

; eof