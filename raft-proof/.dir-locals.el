((coq-mode . ((eval . (set (make-local-variable 'coq-prog-args)
                            (list "-emacs" "-R"
                                  (expand-file-name
                                   "../verdi"
                                   (file-name-directory
                                    (let ((d (dir-locals-find-file ".")))
                                      (if (stringp d) d (car d))))
                                   )
                                  ""
                                  "-R"
                                  (expand-file-name
                                   "../raft"
                                   (file-name-directory
                                    (let ((d (dir-locals-find-file ".")))
                                      (if (stringp d) d (car d))))
                                   )
                                  ""))))))
