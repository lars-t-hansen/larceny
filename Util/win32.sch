; 8 May 2001
;
; General "script" for building Petit Larceny on Win32 systems,
; may be dependent on (Petite) Chez Scheme.
;
; On win32, the DOS shell is not all that useful, so the scripts that 
; are used on Unix have been moved into this Scheme program.  It also
; replaces the Util/load-*.sch programs.

; Loading this file loads the entire build environment.

(define nbuild-parameter #f)

(define is-larceny? #t)

(define (win32-initialize)

  ; The following actions are performed also by load-twobit-C-el-win32-petite.sch,
  ; but they are needed also for bootstrapping the build environment -- without
  ; loading Util/nbuild.sch -- so are included here separately.

  (load "Util\\sysdep-win32.sch")
  (load "Util\\nbuild-param-C-el-win32.sch")
  (if is-larceny?
      (set! nbuild-parameter 
	    (make-nbuild-parameter "" #t #t #t "Larceny" "Petit Larceny"))
      (set! nbuild-parameter 
	    (make-nbuild-parameter "" #t #t #t "Petite" "Petite Chez Scheme")))
  (display "Loading ")
  (display (nbuild-parameter 'host-system))
  (display " compatibility package.")
  (newline)
  (load (string-append (nbuild-parameter 'compatibility) "compat.sch"))
  (compat:initialize)
  (load (string-append (nbuild-parameter 'util) "expander.sch"))
  (load (string-append (nbuild-parameter 'util) "config.sch"))
  (set! config-path "Rts\\Build\\")
  #t)

(define (setup-directory-structure)
  (case (nbuild-parameter 'host-os)
    ((win32)
     (system "mkdir Rts\\Build"))
    (else
     (error "Unknown host OS " (nbuild-parameter 'host-os)))))

(define (build-config-files)
  (case (nbuild-parameter 'host-os)
    ((win32)
     (system "copy Rts\\*.cfg Rts\\Build"))
    (else
     (error "Unknown host OS " (nbuild-parameter 'host-os))))
  (expand-file "Rts\\Standard-C\\arithmetic.mac" "Rts\\Standard-C\\arithmetic.c")
  (config "Rts\\Build\\except.cfg")
  (config "Rts\\Build\\layouts.cfg")
  (config "Rts\\Build\\globals.cfg")
  (config "Rts\\Build\\mprocs.cfg")
  (catfiles '("Rts\\Build\\globals.ch"
	      "Rts\\Build\\except.ch"
	      "Rts\\Build\\layouts.ch"
	      "Rts\\Build\\mprocs.ch")
	    "Rts\\Build\\cdefs.h")
  (catfiles '("Rts\\Build\\globals.sh" 
	      "Rts\\Build\\except.sh" 
	      "Rts\\Build\\layouts.sh")
	    "Rts\\Build\\schdefs.h"))

(define (catfiles input-files output-file)
  (delete-file output-file)
  (call-with-output-file output-file
    (lambda (out)
      (for-each (lambda (f)
		  (call-with-input-file f
		    (lambda (in)
		      (do ((c (read-char in) (read-char in)))
			  ((eof-object? c))
			(write-char c out)))))
		input-files))))

(define (build-runtime-system)
  (execute-in-directory "Rts" "nmake petit-rts.lib"))

(define (build-executable)
  (c-compile-file "petit.c" "petit.obj")
  (c-link-executable "petit.exe" 
		     '("petit.obj") 
		     '("petit-lib.lib" "Rts\\petit-rts.lib")))

(define (load-compiler)
  (if is-larceny?
      (load "Util\\load-twobit-C-el-win32-larceny.sch")
      (load "Util\\load-twobit-C-el-win32-petite.sch")))

(define (remove-rts-objects)
  (system "del Rts\\petit-rts.lib")
  (system "del Rts\\vc60.pdb")
  (system "del Rts\\Sys\\*.obj")
  (system "del Rts\\Standard-C\\*.obj")
  (system "del Rts\\Build\\*.obj")
  #t)

(define (remove-heap-objects . extensions)
  (let ((ext   '("obj" "c" "lap" "lop"))
	(names '(obj c lap lop)))
    (if (not (null? extensions))
	(set! ext (apply append 
			 (map (lambda (n ext)
				(if (memq n extensions) (list ext) '()))
			      names
			      ext))))
    (system "del petit.exe")
    (system "del petit.obj")
    (system "del petit.pdb")
    (system "del petit.heap")
    (system "del petit-lib.lib")
    (system "del petit-lib.pdb")
    (system "del vc60.pdb")
    (for-each (lambda (ext)
		(for-each (lambda (dir) (system (string-append "del " dir "*." ext))) 
			  '("Lib\\Common\\"
			    "Lib\\Standard-C\\"
			    "Repl\\"
			    "Interpreter\\"
			    "Compiler\\")))
	      ext)
    #t))

(win32-initialize)

; Chez Scheme only -- Larceny does not have 'current-directory'.

(define (execute-in-directory dir cmd)
  (with-current-directory dir
    (lambda ()
      (system cmd))))

(define (with-current-directory dir thunk)
  (let ((cdir #f))
    (dynamic-wind
	(lambda ()
	  (set! cdir (current-directory))
	  (current-directory dir))
	thunk
	(lambda ()
	  (set! dir (current-directory))
	  (current-directory cdir)))))

; A hack

(if is-larceny?
    (set! execute-in-directory 
	  (lambda (dir cmd)
	    (call-with-output-file "eid.bat"
	      (lambda (out)
		(display (string-append "cd " dir) out)
		(newline out)
		(display cmd out)
		(newline out)))
	    (system "eid.bat"))))

; eof