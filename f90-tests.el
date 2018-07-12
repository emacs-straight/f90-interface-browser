;;; f90-tests.el --- Tests for f90-interface-browser

;; Copyright (C) 2013  Free Software Foundation, Inc.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'cl-lib)

;; FIXME: Convert to use ERT.

(defvar *test-name* nil)

(defvar *test-tests* (make-hash-table :test 'eq))

(defvar *test-running-tests* nil)
(defmacro deftest (name parameters &rest body)
  "Define a test function. Within a test function we can call
   other test functions or use `check' to run individual test
   cases."
  `(prog1 ',name
     (setf (gethash ',name *test-tests*)
           (lambda ,parameters
             (let ((*test-name* (append *test-name* (list ',name))))
               ,@body)))))

(defmacro test-check (&rest forms)
  "Run each expression in FORMS as a test case."
  `(test-combine-results
    ,@(cl-loop for (expr res) in forms
               collect `(test-report-result (equal (condition-case _
                                                       ,expr
                                                     (error (cl-gensym)))
                                                   ',res)
                                            ',expr ',res))))

(defmacro test-combine-results (&rest forms)
  "Combine the results (as booleans) of evaluating FORMS in order."
  (let ((result (make-symbol "result")))
    `(let ((,result t))
       ,@(cl-loop for f in forms collect `(unless ,f (setf ,result nil)))
       ,result)))

(defun test-report-result (result res req)
  "Report the results of a single test case. Called by `check'."
  (if result
      (insert (format "%s ... %S: %S\n"
                     (propertize "pass"
                                 'face '(:weight bold :foreground "green"))
                     *test-name* res))
    (insert (format "%s ... %S: %S is not %S\n"
                   (propertize "FAIL"
                               'face '(:weight bold :foreground "red"))
                   *test-name*
                   res req)))
  result)

(defun test-run-test (name)
  (with-current-buffer (get-buffer-create "*test-results*")
    (unless *test-running-tests*
      (erase-buffer))
    (let ((*test-running-tests* t))
      (funcall (gethash name *test-tests*)))
    (pop-to-buffer (current-buffer))))

(deftest type-modifiers ()
  (test-check
   ((f90-split-declaration "integer") ("integer"))
   ((f90-split-declaration "integer, pointer") ("integer" "pointer"))
   ((f90-split-declaration "integer (kind = c_int(8)   )") ("integer"))
   ((f90-split-declaration "character(len=*)") ("character"))
   ((f90-split-declaration "integer, dimension(:)")
    ("integer" ("dimension" . 1)))))

(deftest parse-declaration ()
  (cl-flet ((fun (str) (with-temp-buffer
                         (insert str)
                         (goto-char (point-min))
                         (f90-parse-single-type-declaration))))
    (test-check
     ((fun "integer :: name") (("name" "integer")))
     ((fun "integer :: name1, name2") (("name1" "integer")
                                       ("name2" "integer")))
     ((fun "integer, dimension(:) :: name1, name2(:, :)") (("name1" "integer"
                                                            ("dimension" . 1))
                                                           ("name2" "integer"
                                                            ("dimension" . 2))))
     ((fun "integer, pointer :: name(:, :)") (("name" "integer" "pointer"
                                               ("dimension" . 2))))
     ((fun "integer, pointer :: NAmE => null()") (("name" "integer" "pointer"))))))


(deftest splits ()
  (test-check
   ((f90-count-commas ",") 1)
   ((f90-count-commas "(,)") 0)
   ((f90-count-commas "a, b, size(c, d)") 2)
   ((f90-count-commas "a, b, size(c, d)" 1) 3)
   ((f90-split-arglist "a,B") ("a" "b"))
   ((f90-split-arglist "foo, dimension(1, size(a, b))")
    ("foo" "dimension(1, size(a, b))"))
   ((f90-parse-names-list "a=1, B=>null()") ("a" "b"))))

(deftest all ()
  (test-combine-results
   (test-run-test 'type-modifiers)
   (test-run-test 'parse-declaration)
   (test-run-test 'splits)))
