;; Copyright 2012 Ryan Culpepper
;; Copyright 2007-2009 Dimitris Vyzovitis <vyzo at media.mit.edu>
;; 
;; This library is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Lesser General Public License as published
;; by the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;; 
;; This library is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU Lesser General Public License for more details.
;; 
;; You should have received a copy of the GNU Lesser General Public License
;; along with this library.  If not, see <http://www.gnu.org/licenses/>.

#lang racket/base
(require racket/class
         racket/contract/base
         "interfaces.rkt"
         "common.rkt")
(provide
 (contract-out
  [digest
   (-> digest-impl? (or/c input-port? bytes?) bytes?)]
  [digest-impl?
   (-> any/c boolean?)]
  [digest-ctx?
   (-> any/c boolean?)]
  [make-digest-ctx
   (-> digest-impl? digest-ctx?)]
  [digest-size
   (-> (or/c digest-impl? digest-ctx?) nat?)]
  [digest-update!
   (->* (digest-ctx? bytes?) (nat? nat?)
        void?)]
  [digest-final
   (-> digest-ctx? bytes?)]
  [digest-final!
   (->* (digest-ctx? bytes?) (nat? nat?)
        nat?)]
  [digest-copy
   (-> digest-ctx? digest-ctx?)]
  [digest-peek-final
   (-> digest-ctx? bytes?)]
  [digest-peek-final!
   (->* (digest-ctx? bytes?) (nat? nat?)
        nat?)]
  [hmac
   (-> digest-impl? bytes? (or/c bytes? input-port?)
       bytes?)]
  [make-hmac-ctx
   (-> digest-impl? bytes? digest-ctx?)]
  [generate-hmac-key
   (-> digest-impl? bytes?)]))
(provide -digest-port*) ;; for pkey.rkt

(define nat? exact-nonnegative-integer?)

;; ----

(define (digest-impl? x)
  (is-a? x digest-impl<%>))
(define (digest-ctx? x)
  (is-a? x digest-ctx<%>))

(define (make-digest-ctx di)
  (send di new-ctx))

(define (digest-size o)
  (cond [(is-a? o digest-impl<%>) (send o get-size)]
        [(is-a? o digest-ctx<%>) (digest-size (send o get-impl))]))

(define (digest-update! x buf [start 0] [end (bytes-length buf)])
  (send x update! 'digest-update! buf start end))

(define (digest-final dg)
  (let* ([len (digest-size dg)]
         [buf (make-bytes len)])
    (send dg final! 'digest-final buf 0 len)
    buf))

(define (digest-final! dg buf [start 0] [end (bytes-length buf)])
  (send dg final! 'digest-final! buf start end))

(define (digest-copy idg)
  (send idg copy 'digest-copy))

(define (digest-peek-final dg)
  (let* ([len (digest-size dg)]
         [buf (make-bytes len)])
    (send (digest-copy dg) final! 'digest-peek-final buf 0 len)
    buf))

(define (digest-peek-final! dg buf [start 0] [end (bytes-length buf)])
  (send (digest-copy dg) final! 'digest-peek-final! buf start end))

(define (digest di inp)
  (cond [(bytes? inp) (-digest-bytes di inp)]
        [(input-port? inp) (-digest-port di inp)]))

(define (-digest-port type inp)
  (digest-final (-digest-port* type inp)))

(define (-digest-port* di inp)
  (let ([dg (make-digest-ctx di)]
        [ibuf (make-bytes 4096)])
    (let lp ([count (read-bytes-avail! ibuf inp)])
      (cond [(eof-object? count)
             dg]
            [else
             (digest-update! dg ibuf 0 count)
             (lp (read-bytes-avail! ibuf inp))]))))

(define (-digest-bytes di bs)
  (let ([dg (make-digest-ctx di)])
    (digest-update! dg bs)
    (digest-final dg)))

;; ----

(define (make-hmac-ctx di key)
  (let* ([himpl (send di get-hmac-impl 'make-hmac-ctx)])
    (send himpl new-ctx key)))

(define (hmac di key inp)
  (cond [(bytes? inp) (-hmac-bytes di key inp)]
        [(input-port? inp) (-hmac-port di key inp)]))

(define (-hmac-bytes di key buf)
  (or (send di hmac-buffer 'hmac key buf 0 (bytes-length buf))
      (-hmac-port di key (open-input-bytes buf))))

(define (-hmac-port di key inp)
  (let* ([buf (make-bytes 4000)]
         [himpl (send di get-hmac-impl 'hmac)]
         [hctx (send himpl new-ctx key)]
         [size (send himpl get-size)])
    (let loop ()
      (let ([count (read-bytes-avail! buf inp)])
        (cond [(eof-object? count)
               (send hctx final! 'hmac-port buf 0 size)
               (shrink-bytes buf size)]
              [else
               (send hctx update! 'hmac-port buf 0 count)
               (loop)])))))

(define (generate-hmac-key di)
  (send di generate-hmac-key))