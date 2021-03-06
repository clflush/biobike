-;;; -*- mode: Lisp; Syntax: Common-Lisp; Package: bioutils; -*-

(in-package :bioutils)

;;; +=========================================================================+
;;; | Copyright (c) 2002, 2003, 2004 JP Massar, Jeff Shrager, Mike Travers    |
;;; |                                                                         |
;;; | Permission is hereby granted, free of charge, to any person obtaining   |
;;; | a copy of this software and associated documentation files (the         |
;;; | "Software"), to deal in the Software without restriction, including     |
;;; | without limitation the rights to use, copy, modify, merge, publish,     |
;;; | distribute, sublicense, and/or sell copies of the Software, and to      |
;;; | permit persons to whom the Software is furnished to do so, subject to   |
;;; | the following conditions:                                               |
;;; |                                                                         |
;;; | The above copyright notice and this permission notice shall be included |
;;; | in all copies or substantial portions of the Software.                  |
;;; |                                                                         |
;;; | THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,         |
;;; | EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF      |
;;; | MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  |
;;; | IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY    |
;;; | CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,    |
;;; | TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE       |
;;; | SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                  |
;;; +=========================================================================+

;;; Author: JP Massar.

;;;; Code that translates from one form of amino acid representation
;;;; to another (e.g., from the name to the three-letter code).

;;;; Code to compute the molecular weight of a protein.

;;;; Code to translate a DNA sequence into a sequence of amino acids.



(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter *amino-acid-conversion-api-symbols*
    '(
      dna-to-rna-sequence
      rna-to-dna-sequence
      amino-acid-designator?
      aa-to-1-letter-code
      aa-to-3-letter-code
      aa-to-codons
      aa-to-molecular-weight
      aa-to-mw
      ;; what does this really represent?
      ;; aa-to-atoms
      aa-to-long-name
      codon-to-aa
      molecular-weight-of
      translate-d/rna-to-aa
      translate-to-aa
      ncomplement-base-pairs
      ))
  (export *amino-acid-conversion-api-symbols* (find-package :bioutils))
  )


(defparameter *aa-info-hash-table* (make-hash-table :test 'equalp))

(defstruct aa
  full-name
  full-namestring
  full-namestring-lc
  full-namestring-cap
  letter-symbol
  letter-char
  letter-char-lc
  letter-string
  letter-string-lc
  code-symbol
  code-string
  code-string-lc
  code-string-cap
  atoms
  molecular-weight
  codon-symbols
  codon-strings
  codon-strings-lc
  rna-codon-symbols
  rna-codon-strings
  rna-codon-strings-lc
  )

(defparameter *aa-info-list*
  ;; name 1-letter-code 3-letter-code n-atoms mol-weight codons
  '(
    (alanine          A        Ala         5      89.0935  GCT GCC GCA GCG)
    (arginine         R        Arg        11     174.2017  CGT CGC CGA CGG AGA AGG)
    (asparagine       N        Asn         8     132.1184  AAT AAC)
    (aspartic-acid    D        Asp         8     133.1032  GAT GAC )
    (cysteine         C        Cys         6     121.1590  TGT TGC)
    (glutamic-acid    E        Glu         9     147.1299  GAA GAG)
    (glutamine        Q        Gln         9     146.1451  CAA CAG)
    (glycine          G        Gly         4      75.0669  GGT GGC GGA GGG )
    (histidine        H        His        10     155.1552  CAT CAC)
    (isoleucine       I        Ile         8     131.1736  ATT ATC ATA)
    (leucine          L        Leu         8     131.1736  TTA TTG CTT CTC CTA CTG)
    (lysine           K        Lys         9     146.1882  AAA AAG)
    (methionine       M        Met         8     149.2124  ATG)
    (phenylalanine    F        Phe        11     165.1900  TTT TTC)
    (proline          P        Pro         7     115.1310  CCT CCC CCA CCG)
    (serine           S        Ser         6     105.0930  TCT TCC TCA TCG AGT AGC)
    (threonine        T        Thr         7     119.1197  ACT ACC ACA ACG)
    (tryptophan       W        Trp        13     204.2262  TGG)
    (tyrosine         Y        Tyr        11     181.1894  TAT TAC)
    (valine           V        Val         7     117.1469  GTT GTC GTA GTG)
    (stop             *        ***         0          0.0  TAA TAG TGA)
    ))


(defun dna-to-rna-sequence (s &key (in-place? nil))
  "Converts Tt to Uu. The substitution is done in place iff IN-PLACE? is T"
  (funcall 
   (if in-place? 'ntranslate-string 'translate-string)
   s "Tt" "Uu"
   ))

(defun rna-to-dna-sequence (s &key (in-place? nil))
  "Converts Uu to Tt. The substitution is done in place iff IN-PLACE? is T"
  (funcall 
   (if in-place? 'ntranslate-string 'translate-string)
   s "Uu" "Tt"
   ))

(defun aa-info-to-aa-record (aa-info)
  (destructuring-bind
      (name letter code atoms molecular-weight &rest codons)
      aa-info
    (let ((ns (copy-seq (string name)))
          (lc (char (string letter) 0))
          (ls (copy-seq (string letter)))
          (cs (copy-seq (string code))))
      (make-aa
       :full-name name
       :full-namestring ns
       :full-namestring-lc (string-downcase ns)
       :full-namestring-cap (string-capitalize ns)
       :letter-symbol letter
       :letter-char lc
       :letter-char-lc (char-downcase lc)
       :letter-string ls
       :letter-string-lc (string-downcase ls)
       :code-symbol code
       :code-string cs
       :code-string-lc (string-downcase cs)
       :code-string-cap (string-capitalize cs)
       :atoms atoms
       :molecular-weight molecular-weight
       :codon-symbols codons
       :codon-strings 
       (mapcar (lambda (c) (copy-seq (string c))) codons)
       :codon-strings-lc 
       (mapcar (lambda (c) (string-downcase (string c))) codons)
       :rna-codon-symbols
       (mapcar (lambda (c) (intern (dna-to-rna-sequence (string c)))) codons)
       :rna-codon-strings
       (mapcar (lambda (c) (dna-to-rna-sequence (string c))) codons)
       :rna-codon-strings-lc
       (mapcar 
        (lambda (c) (string-downcase (dna-to-rna-sequence (string c))))
        codons
        )))))

(defun create-aa-info-hash-table (aa-info-list)
  (loop for aa-info in aa-info-list do
        (let ((aar (aa-info-to-aa-record aa-info))
              (aaht *aa-info-hash-table*))
          (setf (gethash (aa-full-name aar) aaht) aar)
          (setf (gethash (keywordize (aa-full-name aar)) aaht) aar)
          (setf (gethash (aa-full-namestring aar) aaht) aar)
          (setf (gethash (aa-letter-symbol aar) aaht) aar)
          (setf (gethash (keywordize (aa-letter-symbol aar)) aaht) aar)
          (setf (gethash (aa-letter-char aar) aaht) aar)
          (setf (gethash (aa-letter-string aar) aaht) aar)
          (setf (gethash (aa-code-symbol aar) aaht) aar)
          (setf (gethash (keywordize (aa-code-symbol aar)) aaht) aar)
          (setf (gethash (aa-code-string aar) aaht) aar)
          (loop for codon-symbol in (aa-codon-symbols aar) 
                for rna-codon-symbol in (aa-rna-codon-symbols aar)
                for codon-string in (aa-codon-strings aar) 
                for rna-codon-string in (aa-rna-codon-strings aar) do
                (setf (gethash codon-symbol aaht) aar)
                (setf (gethash (keywordize codon-symbol) aaht) aar)
                (setf (gethash rna-codon-symbol aaht) aar)
                (setf (gethash (keywordize rna-codon-symbol) aaht) aar)
                (setf (gethash codon-string aaht) aar)
                (setf (gethash rna-codon-string aaht) aar)
                )))
  nil)

(create-aa-info-hash-table *aa-info-list*)

(defun gethashaa (key) 
  (or (gethash key *aa-info-hash-table*)
      (and (symbolp key) (not (keywordp key))
           (gethash (keywordize key) *aa-info-hash-table*)
           )))

(defun aa-oops (input)
  (error 
   (formatn
    (one-string
     "Invalid amino acid designator. BioBike does not recognize '~A' as "
     "a way to name an amino acid.")
    input)))

(defun amino-acid-designator? (x) 
  "T if X is a symbol, string or char that denotes an amino acid"
  (not (null (gethashaa x))))

(defun aa-to-1-letter-code (aa &optional (as :string))
  #.(one-string-nl
     "(AA-TO-1-LETTER-CODE amino-acid &optional as)"
     "Takes amino acid"
     "  (1-letter -- character, string or symbol), "
     "  (3-letter -- string or symbol),"
     "  (full name -- string or symbol)"
     "Returns 1-letter code AS "
     ":string :lc-string :symbol :keyword :char or :lcchar")
  (let ((aar (gethashaa aa)))
    (unless aar (aa-oops aa))
    (ecase as
      (:string (aa-letter-string aar))
      ((:lcstring :lc-string) (aa-letter-string-lc aar))
      (:symbol (aa-letter-symbol aar))
      (:keyword (keywordize (aa-letter-symbol aar)))
      ((:char :character) (aa-letter-char aar))
      ((:lcchar :lc-char :lccharacter :lc-character) (aa-letter-char-lc aar))
      )))

(defun aa-to-3-letter-code (aa &optional (as :string))
  #.(one-string-nl
     "(AA-TO-3-LETTER-CODE amino-acid &optional as)"
     "Takes amino acid"
     "  (1-letter -- character, string or symbol), "
     "  (3-letter -- string or symbol),"
     "  (full name -- string or symbol)"
     "Returns 3-letter code AS "
     ":string :lcstring :capstring :symbol or :keyword")
  (let ((aar (gethashaa aa))) 
    (unless aar (aa-oops aa))
    (ecase as
      (:string (aa-code-string aar))
      ((:lcstring :lc-string) (aa-code-string-lc aar))
      ((:capstring :cap-string) (aa-code-string-cap aar))
      (:symbol (aa-code-symbol aar))
      (:keyword (keywordize (aa-code-symbol aar)))
      )))

(defun aa-to-codons (aa &optional (as :strings))
  #.(one-string-nl
     "(AA-TO-CODONS amino-acid &optional as)"
     "Takes amino acid"
     "  (1-letter -- character, string or symbol), "
     "  (3-letter -- string or symbol),"
     "  (full name -- string or symbol)"
     "Returns list of codons that encode amino acid AS"
     ":strings :lcstrings :symbols :keywords "
     ":rna-strings :rna-lcstrings :rna-symbols")
  (let ((aar (gethashaa aa)))
    (unless aar (aa-oops aa))
    (ecase as
      ((:strings :string) (aa-codon-strings aar))
      ((:lcstrings :lc-strings :lcstring :lc-string) (aa-codon-strings-lc aar))
      ((:capstring :cap-string) (mapcar 'string-capitalize (aa-codon-strings-lc aar)))
      ((:symbol :symbols) (aa-codon-symbols aar))
      ((:keywords :keyword) (mapcar 'keywordize (aa-codon-symbols aar)))
      ((:rna-strings :rna-string) (aa-rna-codon-strings aar))
      ((:rna-lcstrings :rna-lcstring :rna-lc-strings :rna-lc-string)
       (aa-rna-codon-strings-lc aar))
      ((:rna-capstring :rna-cap-string) 
       (mapcar 'string-capitalize (aa-rna-codon-strings-lc aar)))
      ((:rna-symbols :rna-symbol) (aa-rna-codon-symbols aar))
      ((:rna-keyword :rna-keywords) (mapcar 'keywordize (aa-rna-codon-symbols aar)))
      )))


(defun aa-to-molecular-weight (aa &optional (as :single-float))
  #.(one-string-nl
     "(AA-TO-MOLECULAR-WEIGHT amino-acid &optional as)"
     "Takes amino acid"
     "  (1-letter -- character, string or symbol), "
     "  (3-letter -- string or symbol),"
     "  (full name -- string or symbol)"
     "Returns molecular weight of amino acid AS"
     ":integer :fixnum :single-float :double-float")
  (aa-to-mw aa as))

(defun aa-to-mw (aa &optional (as :single-float))
  #.(one-string-nl
     "(AA-TO-MW amino-acid &optional as)"
     "Takes amino acid"
     "  (1-letter -- character, string or symbol), "
     "  (3-letter -- string or symbol),"
     "  (full name -- string or symbol)"
     "Returns molecular weight of amino acid AS"
     ":integer :fixnum :single-float :double-float")
  (let* ((aar (gethashaa aa))) 
    (unless aar (aa-oops aa))
    (let ((mw (aa-molecular-weight aar)))
      ;; No longer valid. JP 12/27/12
      ;; (declare (fixnum mw))
      (ecase as
        ((:integer :fixnum) (round mw))
        ((:single-float :sfloat :float) (float mw 0.0))
        ((:double-float :dfloat :double) (float mw 0.0d0))
        ))))
       
(defun aa-to-atoms (aa)
  #.(one-string-nl
     "(AA-TO-ATOMS amino-acid &optional as)"
     "Takes amino acid"
     "  (1-letter -- character, string or symbol), "
     "  (3-letter -- string or symbol),"
     "  (full name -- string or symbol)"
     "Returns number of atoms in amino acid")
  (let ((aar (gethashaa aa))) 
    (unless aar (aa-oops aa))
    (aa-atoms aar)))


(defun aa-to-long-name (aa &optional (as :string))
  #.(one-string-nl
     "(AA-TO-LONG-NAME amino-acid &optional as)"
     "Takes amino acid"
     "  (1-letter -- character, string or symbol), "
     "  (3-letter -- string or symbol),"
     "  (full name -- string or symbol)"
     "Returns full name of amino acid AS"
     ":string :lcstring :capstring :symbol :keyword")
  (let ((aar (gethashaa aa))) 
    (unless aar (aa-oops aa))
    (ecase as
      (:string (aa-full-namestring aar))
      ((:lcstring :lc-string) (aa-full-namestring-lc aar))
      ((:capstring :cap-string) (aa-full-namestring-cap aar))
      (:symbol (aa-full-name aar))
      (:keyword (keywordize (aa-full-name aar)))
      )))

(defun codon-to-aa (codon &optional (as :string))
  #.(one-string-nl
     "(CODON-TO-AA codon &optional as)"
     "Takes 3-letter codon (symbol or string)"
     "Returns 1-letter code of amino acid encoded by the codon, or '-' AS"
     ":character :string :lcstring :symbol :keyword")
  (let ((aar (gethashaa codon))) 
    (if aar
        (ecase as
          ((:char :character) (aa-letter-char aar))
          ((:lcchar :lc-character) (char-downcase (aa-letter-char aar)))
          (:string (aa-letter-string aar))
          ((:lcstring :lc-string) (aa-letter-string-lc aar))
          (:symbol (aa-letter-symbol aar))
          (:keyword (keywordize (aa-letter-symbol aar))))
      (ecase as
        ((:char :character :lcchar :lc-character) #\-)
        ((:string :lcstring :lc-string) "-")
        (:symbol '-)
        (:keyword :-)
        ))))



(defun molecular-weight-of (aa-sequence)
  #.(one-string-nl
     "(MOLECULAR-WEIGHT-OF aa-sequence)"
     "returns the molecular weight of the amino acid sequence as a float")
  #.(optimization-declaration)
  (let ((total-mw 0.0)
        (seq-len 0))
    (declare (single-float total-mw))
    (cond
     ((typep aa-sequence 'simple-string)
      (loop for pos fixnum from 0 below (length aa-sequence)
            as aa = (schar aa-sequence pos)
            UNTIL (EQUAL aa #\*)
            as mw of-type single-float = (aa-to-mw aa)
            do (incf total-mw mw)
               (INCF seq-len)))
     (t
      (loop for pos fixnum from 0 below (length aa-sequence)
            as aa = (char aa-sequence pos)
            UNTIL (EQUAL aa #\*)
            as mw of-type single-float = (aa-to-mw aa)
            do (incf total-mw mw)
               (INCF seq-len))))
    (- total-mw (* 18 (- seq-len 1)))
    ))

(defun translate-d/rna-to-aa 

       (d/rna-sequence 
        &KEY (as :1codes) (separator "" separator-provided?) 
        (if-partial-codon :error) (if-unknown-codon :error)
        (insist-on nil))

  #.(one-string-nl
     "(TRANSLATE-D/RNA-TO-AA"
     "  d/rna-sequence &key as separator if-partial-codon if-unknown-codon)"
     "Translates DNA or RNA sequence to amino acid sequence."
     "Returns string of amino acids, either as 1-letter codes "
     "(:as :1codes), the default, or as 3-letter codes (:as :3codes) "
     "Each amino acid is separated by nothing (default for :1codes) or a"
     "single space (default for :3codes) or the provided separator string"
     "SEPARATOR."
     "If the sequence is not a multiple of 3 characters long, IF-PARTIAL-CODON"
     "specifies whether to signal an error (:error), a warning (:warn)"
     "or ignore the excess terminating characters (:ignore)."
     "IF-UNKNOWN-CODON specifies what to do if an unknown codon is detected"
     "in the sequence.  Possibilities are to signal an error (:error), a"
     "warning (:warn), or, if IF-UNKNOWN-CODON is a character or string to"
     "use that value as the translation, or if it is anything else to use"
     "the default (#\- or '---') as the translation."
     "If INSIST-ON is :DNA or :RNA, each codon is checked to insure that it"
     "does not contain 'U' or 'T' respectively. The default, NIL, allows both")

  (block exit

    ;; First figure out how big the translation is going to be
    ;; and allocate a string of that size.

    (let* ((seqlen (length d/rna-sequence))
           (separator (coerce separator 'simple-string))
           (codon (make-string 3))
           (n-translations (/ seqlen 3))
           (tunit-size
            (ecase as
              ((:char :chars :character :characters :code1 :1code :1codes) 1)
              ((:code3 :code3-strings :3code :3codes :3code-strings) 
               (unless separator-provided? (setq separator " "))
               3)))
           (seplen (length separator))
           (tdelta (+ tunit-size seplen)))
      (declare (fixnum seqlen seplen tunit-size))
      (declare (fixnum tdelta))
      (declare (simple-string separator codon))
      (unless (integerp n-translations)
        (ecase if-partial-codon
          (:error (error "D/RNA sequence is not a multiple of 3 long!!"))
          (:warn (warn "D/RNA sequence is not a multiple of 3"))
          ((:ignore :truncate nil) nil))
        (setq n-translations (floor n-translations)))
      (let ((total-translation-size
             (- (* n-translations (+ tunit-size seplen)) seplen)))
        (when (not (plusp total-translation-size))
          (return-from exit ""))
        (let ((translated-string (make-string total-translation-size))
              (n-translations n-translations))
          (declare (fixnum n-translations))

          ;; Now loop for every three characters in D/RNA-SEQUENCE
          ;; translating the 3-character codon into an amino acid.
          ;; Ignore excess characters, if any, at the end.

          (LOOP FOR coord fixnum FROM 0 BELOW (- seqlen 2) BY 3
                for tcoord fixnum from 0 by tdelta 
                for n fixnum from 1 do
                (loop for j fixnum from coord 
                      for i fixnum from 0 below 3 do
                      (setf (schar codon i) (char d/rna-sequence j)))
                (when insist-on
                  (ecase insist-on
                    (:dna 
                     (when (find #\U codon :test 'char-equal)
                       (error 
                        "RNA char ~S in codon ~S in DNA sequence at pos ~D"
                        #\U codon coord)))
                    (:rna
                     (when (find #\T codon :test 'char-equal)
                       (error 
                        "DNA char ~S in codon ~S in RNA sequence at pos ~D"
                        #\T codon coord)))))
                (cond
                 ((= tunit-size 1)
                  (let ((code-char (codon-to-aa codon :character)))
                    (when (eql code-char #\-)
                      (case if-unknown-codon
                        (:error 
                         (error "Unknown codon ~S, position ~D" codon coord))
                        (:warn 
                         (warn "Unknown codon ~S, position ~D" codon coord))
                        (otherwise
                         (cond
                          ((characterp if-unknown-codon)
                           (setq code-char if-unknown-codon))
                          ((stringp if-unknown-codon)
                           (setq code-char (char if-unknown-codon 0)))
                          (t nil)
                          ))))
                    (setf (schar translated-string tcoord) code-char)))
                 ((= tunit-size 3)
                  (let ((code-symbol (codon-to-aa codon :symbol)) 
                        code-string)
                    (if (eq code-symbol '-)
                        (case if-unknown-codon
                          (:error 
                           (error "Unknown codon ~S, position ~D" codon coord))
                          (:warn 
                           (warn "Unknown codon ~S, position ~D" codon coord)
                           (setq code-string "---"))
                          (otherwise
                           (setq code-string
                                 (if (stringp if-unknown-codon)
                                     if-unknown-codon "---"))))
                      (setq code-string 
                            (aa-to-3-letter-code (codon-to-aa codon :symbol))))
                    (loop for j fixnum from tcoord
                          for i fixnum from 0 below 3 do
                          (setf (schar translated-string j) 
                                (schar code-string i)
                                ))))
                 (t (error "Internal error. Invalid translation unit size.")))

                ;; Add the separation string if it exists and
                ;; this isn't the very last iteration.

                (when (and (plusp seplen) (/= n n-translations))
                  (loop for j from (the fixnum (+ tcoord tunit-size))
                        for i from 0 below seplen do
                        (setf (schar translated-string j) (schar separator i))
                        )))

          translated-string

          )))))

(defun translate-to-aa (&rest args)
  "Alias for (TRANSLATE-D/RNA-TO-AA ...  See documentation for that function."
  (apply 'translate-d/rna-to-aa args))

(defvar *base-translations* 
  (let* ((chars "acgtnrywsmkbvdhACGTNRYWSMKBVDH")
         (translations "tgcanyrwskmvbhdTGCANYRWSKMVBHD")
         (max (reduce 'max (map 'list 'char-code chars)))
         (tarray (make-string (1+ max) :initial-element #\!)))
    (loop for c across chars for tc across translations do 
          (setf (aref tarray (char-code c)) tc))
    tarray
    ))    

(defun ncomplement-base-pairs 
       (string 
        &key 
        (reverse? t) (extended-alphabet? nil) (if-invalid-char? nil)
        &aux (translations *base-translations*))
  #.(optimization-declaration)
  (declare (type simple-string translations))
  #.(one-string-nl
     "Complements (in the DNA sense) a simple string in place."

     "By default, the complemented string's characters are returned"
     "in reverse order.  If REVERSE? is NIL (default T), the complemented"
     "string's characters are returned in the original order."

     "Characters which are not ACGTacgt are not complemented. However if"
     "EXTENDED-ALPHABET? is T, then an extended alphabet is permitted,"
     "which is complemented as follows:"
     "  N -> N  (Any base pair)"
     "  R -> Y  (A or G -> C or T)"
     "  Y -> R  (C or T -> A or G)"
     "  W -> W  (A or T -> A or T)"
     "  S -> S  (G or C -> G or C)"
     "  M -> K  (A or C -> G or T)"
     "  K -> M  (G or C -> A or T)"
     "  B -> V  (C, G, or T -> A, C, or G)"
     "  V -> B (A, C, or G -> C, G, or T)"
     "  D -> H (A, G, or T -> A, C, or T)"
     "  H -> D (A, C, or T -> A, G, or T)"
     "(Lowercase also permitted)"
     ""
     "IF-INVALID-CHAR? determines the behavior if an invalid character"
     "is detected.  The default is NIL which means leave the character in"
     "place.  The other options are: :error, which causes an error to be"
     "signaled, and :warn, which causes a warning to be issued."
     ""
     "Note: The operation is destructive, the string is modified in place."
     "Use COPY-SEQ to copy the string if this is not desirable."
     )
  (if (not (simple-string-p string))
      (let ((result (ncomplement-base-pairs 
                     (coerce string 'simple-string)
                     :reverse? reverse? 
                     :extended-alphabet? extended-alphabet?
                     :if-invalid-char? if-invalid-char?
                     )))
        (replace string result))
    (locally 
      (declare (type simple-string string))
      (cond
       ((and (null extended-alphabet?) (null if-invalid-char?))
        (ncomplement-base-pairs-fast string))
       ((and extended-alphabet? (null if-invalid-char?))
        (loop for k fixnum from 0 below (length string) 
              for ch = (aref string k)
              as tr = (aref translations (the fixnum (char-code ch)))
              unless (char= tr #\!)
              do (setf (schar string k) tr)
              ))
       (t 
        (loop
         for k fixnum from 0 below (length string)
         for ch = (aref string k)
         as tr = (aref translations (the fixnum (char-code ch)))
         do
         (if (not (char= tr #\!))
             (setf (schar string k) tr)
           (case if-invalid-char? 
             (:warn 
              (warn "Unrecognized base '~A' found at position ~D" ch k))
             (otherwise
              (error "Unrecognized base '~A' found at position ~D" ch k))
             )))))))
  (if reverse? (nreverse string) string)
  )

(defun ncomplement-base-pairs-fast (sstring)
  #.(optimization-declaration)
  (declare (simple-string sstring))
  (loop for j fixnum below (length sstring) 
        as ch = (schar sstring j) do
        (setf (schar sstring j)
              (case ch
                (#\a #\t) (#\A #\T)
                (#\c #\g) (#\C #\G)
                (#\g #\c) (#\G #\C)
                (#\t #\a) (#\T #\A)
                (otherwise ch)
                )))
  sstring)
