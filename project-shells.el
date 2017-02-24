;;; project-shells.el --- Manage shells of projects -*- lexical-binding: t -*-

;; Copyright (C) 2017 "Huang, Ying" <huang.ying.caritas@gmail.com>

;; Author: "Huang, Ying" <huang.ying.caritas@gmail.com>
;; URL: https://github.com/hying-caritas/project-shells
;; Package-Version: 20170222
;; Keywords: project, shell, terminal
;; Package-Requires: ((pkg-info "0.4"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; Manage multiple shell/terminal buffers for each project.

(require 'cl-lib)

(defvar-local project-shells-project-name nil)
(defvar-local project-shells-project-root nil)

;;; Customization
(defgroup project-shells nil
  "Manage shells of projects"
  :group 'tools
  :link '(url-link :tag "Github" "https://github.com/hying-caritas/project-shells"))

(defcustom project-shells-default-shell-name "sh"
  "The default shell buffer name"
  :group 'project-shells
  :type 'string)

(defcustom project-shells-empty-project "-"
  "Specify the name of the empty project.

This is used to create non-project specific shells."
  :group 'project-shells
  :type 'string)

(defcustom  project-shells-setup `((,project-shells-empty-project .
				      (("1" .
					(,project-shells-default-shell-name
					 "~/" 'shell nil)))))
  "Specify the setup for shells of each project.

Including name, initial directory, type, function to intialize,
etc."
  :group 'project-shells
  :type '(alist :key-type (string :tag "Project") :value-type
		(alist :tag "Project setup"
		       :key-type  (string :tag "Key")
		       :value-type (list :tag "Shell setup"
					 (string :tag "Name")
					 (string :tag "Directory")
					 (choice :tag "Type" (const term) (const shell))
					 (choice :tag "Function" (const nil) function)))))

(defcustom project-shells-keys '("1" "2" "3" "4" "5" "6" "7" "8" "9" "0" "-" "=")
  "Specify keys for shells, one shell will be created for each key.

Usually these key will be bound in a non-global keymap."
  :group 'project-shells
  :type '(repeat string))

(defcustom project-shells-term-keys '("-" "=")
  "Specify keys to create terminal.

By default shell mode will be used, but for keys in
project-shells-term-keys, ansi terminal mode will be used.  This
should be a subset of *poject-shells-keys*."
  :group 'project-shells
  :type '(repeat string))

(defcustom project-shells-project-name-func 'projectile-project-name
  "Specify function to get project name."
  :group 'project-shells
  :type 'function)

(defcustom project-shells-project-root-func 'projectile-project-root
  "Specify function to get project root directory"
  :group 'project-shells
  :type 'function)

(defcustom project-shells-histfile-env "HISTFILE"
  "Specify environment variable to set shell history file"
  :group 'project-shells
  :type 'string)

(defcustom project-shells-histfile-name ".shell_history"
  "Specify shell history file name"
  :group 'project-shells
  :type 'string)

(defcustom project-shells-term-args nil
  "Specify shell argument used in terminal"
  :group 'project-shells
  :type 'string)

(let ((saved-shell-buffer-list nil)
      (last-shell-name))
  (cl-defun shell-buffer-list ()
    (setf saved-shell-buffer-list
	  (cl-remove-if-not #'buffer-live-p saved-shell-buffer-list)))
  (cl-defun project-shells-switch (&optional name to-create)
    (interactive "bShell: ")
    (let* ((name (or name last-shell-name))
	   (buffer-list (shell-buffer-list))
	   (buf (when name
		  (cl-find-if (lambda (b) (string= name (buffer-name b)))
			      buffer-list))))
      (when (and (or buf to-create)
		 (cl-find (current-buffer) buffer-list))
	(setf last-shell-name (buffer-name (current-buffer))))
      (if buf
	  (progn
	    (select-window (display-buffer buf))
	    buf)
	(unless to-create
	  (message "No such shell: %s" name)
	  nil))))
  (cl-defun project-shells-switch-to-last ()
    (interactive)
    (let ((name (or (and last-shell-name (get-buffer last-shell-name)
			 last-shell-name)
		    (and (shell-buffer-list)
			 (buffer-name (first (shell-buffer-list)))))))
      (if name
	  (project-shells-switch name)
	(message "No more shell buffers!"))))
  (cl-defun project-shells-create (name dir &optional (type 'shell) func)
    (let ((default-directory (expand-file-name (or dir "~/"))))
      (cl-ecase type
	('term (ansi-term "/bin/sh"))
	('shell (shell)))
      (rename-buffer name)
      (push (current-buffer) saved-shell-buffer-list)
      (when func (funcall func)))))

(cl-defun project-shells-create-switch (name dir &optional (type 'shell) func)
  (unless (project-shells-switch name t)
    (project-shells-create name dir type func)))

(cl-defun project-shells-send-shell-command (cmdline)
  (insert cmdline)
  (comint-send-input))

(cl-defun project-shells-project-name ()
  (or project-shells-project-name (funcall project-shells-project-name-func)
      project-shells-empty-project))

(cl-defun project-shells-project-root (proj-name)
  (if (string= proj-name project-shells-empty-project)
      "~/"
    (or project-shells-project-root
	(funcall project-shells-project-root-func))))

(cl-defun project-shells-set-histfile-env (val)
  (when (and project-shells-histfile-env
	     project-shells-histfile-name)
    (setenv project-shells-histfile-env val)))

(cl-defun project-shells-escape-sh (str)
  (replace-regexp-in-string
   "\"" "\\\\\""
   (replace-regexp-in-string "\\\\" "\\\\\\\\" str)))

(cl-defun project-shells-command-string (args)
  (mapconcat
   #'identity
   (cl-loop
    for arg in args
    collect (concat "\"" (project-shells-escape-sh arg) "\""))
   " "))

(cl-defun project-shells-term-command-string ()
  (let* ((prog (or explicit-shell-file-name
		   (getenv "ESHELL") shell-file-name)))
    (concat "exec " (project-shells-command-string
		     (cons prog project-shells-term-args)) "\n")))

(cl-defun project-shells-activate (key &optional proj proj-root)
  (let* ((proj (or proj (project-shells-project-name)))
	 (proj-root (or proj-root (project-shells-project-root proj)))
	 (proj-shells (cdr (assoc proj project-shells-setup)))
	 (shell-info (cdr (assoc key proj-shells)))
	 (name (or (first shell-info) project-shells-default-shell-name))
	 (dir (or (second shell-info) proj-root))
	 (type (or (third shell-info)
		   (if (member key project-shells-term-keys)
		       'term 'shell)))
	 (func (fourth shell-info))
	 (shell-name (format "*%s.%s.%s*" key name proj))
	 (session-dir (expand-file-name (format "~/.sessions/%s/%s" proj key))))
    (mkdir session-dir t)
    (project-shells-set-histfile-env
     (format "%s/%s" session-dir project-shells-histfile-name))
    (project-shells-create-switch
     shell-name dir type
     (lambda ()
       (when func
	 (funcall func session-dir))
       (when (eq type 'term)
	 (term-send-raw-string (project-shells-term-command-string)))
       (setf project-shells-project-name proj
	     project-shells-project-root proj-root)))
    (project-shells-set-histfile-env nil)))

(cl-defun project-shells-setup (map &optional setup)
  (when setup
    (setf project-shells-setup setup))
  (cl-loop
   for key in project-shells-keys
   do (define-key map (kbd key)
	(let* ((key key))
	  (lambda (p)
	    (interactive "p")
	    (project-shells-activate
	     key (and (/= p 1) project-shells-empty-project)))))))

(provide 'project-shells)
