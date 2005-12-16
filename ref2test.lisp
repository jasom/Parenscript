(in-package :js-test) 
;;Generates automatic tests from the reference

(defparameter +reference-file+ (make-pathname :name "reference"
                                              :type "lisp"
                                              :defaults *load-truename*))
(defparameter +generate-file+ (make-pathname :name "reference-tests"
                                              :type "lisp"
                                              :defaults *load-truename*))

(defparameter +head+ "(in-package :js-test)
;; Tests of everything in the reference.
;; File is generated automatically from the text in reference.lisp by
;; the function make-reference-tests-dot-lisp in ref2test.lisp
;; so do not edit this file.
(def-suite ref-tests)
(in-suite ref-tests)~%~%") ; a double-quote for emacs: "
  
(defun make-reference-tests-dot-lisp()
  (let ((built "")
        heading
        heading-count)
    (with-open-file (out-stream +generate-file+
                                :direction :output
                                :if-exists :supersede)
      (labels 
          ((empty-p (str)
             (zerop (length str)))
           (trim-whitespace (str)
             (string-trim '(#\Space #\Tab #\Newline) str))
           (left (str count)
             (subseq str 0 (min count (length str))))
           (lispify-heading (heading)
             (remove-if (lambda (ch) (or (char= ch #\`)(char= ch #\')))
                        (substitute  #\- #\Space (string-downcase (trim-whitespace heading))
                                     :test #'char=)))
           (clean-quotes (str)
             (substitute  #\' #\"  str :test #'char=))
           (strip-indentation (str indentation)
             (if indentation
                 (js::string-join (mapcar #'(lambda (str)
                                          (if (> (length str) indentation)
                                              (subseq str indentation)
                                              str))
                                      (js::string-split str (list #\Newline)))
                              (string #\Newline))
                 str))

           (make-test ()
             (let* ((sep-pos (search "=>" built))
                    (cr-before-sep  (when sep-pos
                                      (or (position #\Newline
                                                    (left built sep-pos)
                                                    :from-end t
                                                    :test #'char=)
                                          0)))
                    (js-indent-width (when cr-before-sep
                                       (+ 2 (- sep-pos cr-before-sep))))
                    (lisp-part (and sep-pos (left built sep-pos)))
                    (javascript-part (when cr-before-sep
                                       (subseq built (+ 1 cr-before-sep)))))
               (cond
                 ((null sep-pos)
                  (print "Warning, separator not found"))
                 ((search "=>" (subseq built (+ 1 sep-pos)))
                  (print "Error , two separators found"))
                 ((and (string= heading "regular-expression-literals")
                       (= 2 heading-count)) ;requires cl-interpol reader
                  (print "Skipping regex-test two"))
                 ((and lisp-part javascript-part)
                  (format out-stream "(test-ps-js ~a-~a ~%  ~a ~%  ~S)~%~%"
                          heading heading-count
                          (trim-whitespace lisp-part)
                          (clean-quotes (strip-indentation javascript-part js-indent-width))))
                 (t (print "Error, should not be here"))))))
        (format out-stream +head+)
        (with-open-file (stream +reference-file+ :direction :input)
          (loop for line = (read-line stream nil nil)
                with is-collecting
                while line do
                (cond
                  ((string= (left line 4) ";;;#")
                   (setf heading (lispify-heading (subseq line 5)))
                   (setf heading-count 0)
                   (when (string= (trim-whitespace heading)
                                  "the-parenscript-compiler")
                     (return)))
                  ((string= (left line 1) ";") 'skip-comment)
                  ((empty-p (trim-whitespace line))
                   (when is-collecting
                     (setf is-collecting nil)
                     (incf heading-count)
                     (make-test)
                     (setf built "")))
                  (t
                   (setf is-collecting t
                         built (concatenate 'string built
                                            (when (not (empty-p built))
                                              (list #\Newline))
                                            line))))))
        (format out-stream "~%(run! 'ref-tests)~%")))))
