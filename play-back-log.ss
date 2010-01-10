#! /bin/sh
#| Hey Emacs, this is -*-scheme-*- code!
exec mzscheme -l errortrace --require $0 --main -- ${1+"$@"}
|#

#lang scheme

(define-values (*pipe-ip* *pipe-op*) (make-pipe))

(define *leading-crap* #px"^........................ <= ")
(define *length-of-leading-crap* 28)

;; Read lines from the log, discard some, massage the rest, and put
;; each of those into the pipe.
(define putter
  (thread
   (lambda ()
     (let ([ip (open-input-file "big-log")])
       (for ([line (in-lines ip)]
             #:when (((curry regexp-match) *leading-crap*) line))
         (display (read (open-input-string (substring line *length-of-leading-crap*))) *pipe-op*)
         (newline *pipe-op*))
       (close-output-port *pipe-op*)))))

(provide main)
(define (main)

  (define oddballs '())
  (define tables
    (make-immutable-hash
     (map
      (lambda (name) (cons name (make-hash)))
      '(servers numeric-verbs lone-verbs speakers verbs))))

  (define (inc! dict-name key) (dict-update! (hash-ref tables dict-name) key add1 1))

  (define (hprint d)
    (pretty-print
     (sort #:key cdr
           (hash-map (hash-ref tables d) cons)
           <)))

  (for ([line (in-lines *pipe-ip*)]
        [lines-processed (in-naturals)])

    (cond
     ((and (positive? (string-length line))
           (equal? #\: (string-ref line 0)))
      (let ([line (substring line 1)])
        (match line
          ;; ":lindbohm.freenode.net 002 rudybot :Your host is lindbohm.freenode.net ..."
          [(pregexp #px"^(\\S+) ([0-9]{3}) (\\S+) .*$" (list _ servername number-string target))
           (inc! 'servers servername)
           (inc! 'numeric-verbs number-string)]

          ;; "alephnull!n=alok@122.172.25.154 PRIVMSG #emacs :subhadeep: ,,doctor"
          [(pregexp #px"^(\\S+) (\\S+) (\\S+) :(.*)$" (list _ speaker verb target text))
           (inc! 'speakers speaker)
           (inc! 'verbs verb)
           ]
          ;; "rudybot!n=luser@q-static-138-125.avvanta.com JOIN :#scheme"
          [
           (pregexp #px"^(\\S+) (\\S+) :(.*)$" (list _ speaker verb text))
           (inc! 'speakers speaker)
           (inc! 'verbs verb)
           ]

          ;; "ChanServ!ChanServ@services. MODE #scheme +o arcfide "
          [
           (pregexp #px"^(\\S+) ((\\S+) )+" (list _ speaker words ...))
           (inc! 'speakers speaker)
           ]
          )))
     (else
      ;; non-colon lines -- pretty much just NOTICE and PING
      (match line
        [(pregexp #px"^(.+?) " (list _ verb))
         (inc! 'lone-verbs verb)
         ])
      )))

  (for ([k (in-hash-keys tables)])
    (printf "~a seen: " k)
    (hprint k))

  (printf "Oddballs: ")
  (pretty-print oddballs)

  (kill-thread putter))