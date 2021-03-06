;;; project-shells.el --- Manage the shell buffers of each project -*- lexical-binding: t -*-

;; Copyright (C) 2017 "Huang, Ying" <huang.ying.caritas@gmail.com>

;; Author: "Huang, Ying" <huang.ying.caritas@gmail.com>
;; Maintainer: "Huang, Ying" <huang.ying.caritas@gmail.com>
;; URL: https://github.com/hying-caritas/project-shells
;; Version: 20170222
;; Package-Version: 20170222
;; Package-Type: simple
;; Keywords: processes, terminals
;; Package-Requires: ((emacs "24.3"))

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

;; Manage multiple shell/terminal buffers for each project.  For
;; example, to develop for Linux kernel, I usually use one shell
;; buffer to configure and build kernel, one shell buffer to run some
;; git command not supported by magit, one shell buffer to run qemu
;; for built kernel, one shell buffer to ssh into guest system to
;; test.  Different set of commands is used by the shell in each
;; buffer, so each shell should have different command history
;; configuration, and for some shell, I may need different setup.  And
;; I have several projects to work on.  In addition to project
;; specific shell buffers, I want some global shell buffers, so that I
;; can use them whichever project I am working on.  Project shells is
;; an Emacs program to let my life easier via helping me to manage all
;; these shell/terminal buffers.

;;; Code:

(require 'cl-lib)

(defvar-local project-shells-project-name nil)
(defvar-local project-shells-project-root nil)

;;; Customization
(defgroup project-shells nil
  "Manage shell buffers of each project"
  :group 'tools
  :link '(url-link :tag "Github" "https://github.com/hying-caritas/project-shells"))

(defcustom project-shells-default-shell-name "sh"
  "Default shell buffer name."
  :group 'project-shells
  :type 'string)

(defcustom project-shells-empty-project "-"
  "Name of the empty project.

This is used to create non-project specific shells."
  :group 'project-shells
  :type 'string)

(defcustom project-shells-setup `((,project-shells-empty-project .
				   (("1" .
				     (,project-shells-default-shell-name
				      "~/" shell nil)))))
  "Configration form for shells of each project.

The format of the variable is an alist which maps the project
name (string) to the project shells configuration.  Which is an
alist which maps the key (string) to the shell configuration.
Which is a list of shell name (string), initial
directory (string), type ('shell or 'term), and intialization
function (symbol or lambda)."
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
  "Keys used to create shell buffers.

One shell will be created for each key.  Usually these key will
be bound in a non-global keymap."
  :group 'project-shells
  :type '(repeat string))

(defcustom project-shells-term-keys '("-" "=")
  "Keys used to create terminal buffers.

By default shell mode will be used, but for keys in
‘project-shells-term-keys’, ansi terminal mode will be used.  This
should be a subset of *poject-shells-keys*."
  :group 'project-shells
  :type '(repeat string))

(defcustom project-shells-session-root "~/.sessions"
  "The root directory for the shell sessions."
  :group 'project-shells
  :type 'string)

(defcustom project-shells-project-name-func 'projectile-project-name
  "Function to get project name."
  :group 'project-shells
  :type 'function)

(defcustom project-shells-project-root-func 'projectile-project-root
  "Function to get project root directory."
  :group 'project-shells
  :type 'function)

(defcustom project-shells-histfile-env "HISTFILE"
  "Environment variable to set shell history file."
  :group 'project-shells
  :type 'string)

(defcustom project-shells-histfile-name ".shell_history"
  "Shell history file name used to set environment variable."
  :group 'project-shells
  :type 'string)

(defcustom project-shells-term-args nil
  "Shell arguments used in terminal."
  :group 'project-shells
  :type 'string)

(let ((saved-shell-buffer-list nil)
      (last-shell-name nil))
  (cl-defun project-shells--buffer-list ()
    (setf saved-shell-buffer-list
	  (cl-remove-if-not #'buffer-live-p saved-shell-buffer-list)))

  (cl-defun project-shells--switch (&optional name to-create)
    (let* ((name (or name last-shell-name))
	   (buffer-list (project-shells--buffer-list))
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
    "Switch to the last shell buffer."
    (interactive)
    (let ((name (or (and last-shell-name (get-buffer last-shell-name)
			 last-shell-name)
		    (and (project-shells--buffer-list)
			 (buffer-name (first (project-shells--buffer-list)))))))
      (if name
	  (project-shells--switch name)
	(message "No more shell buffers!"))))

  (cl-defun project-shells--create (name dir &optional (type 'shell) func)
    (let ((default-directory (expand-file-name (or dir "~/"))))
      (cl-ecase type
	(term (ansi-term "/bin/sh"))
	(shell (shell)))
      (rename-buffer name)
      (push (current-buffer) saved-shell-buffer-list)
      (when func (funcall func)))))

(cl-defun project-shells--create-switch (name dir &optional (type 'shell) func)
  (unless (project-shells--switch name t)
    (project-shells--create name dir type func)))

(cl-defun project-shells-send-shell-command (cmdline)
  "Send the command line to the current (shell) buffer.  Can be
used in shell initialized function."
  (insert cmdline)
  (comint-send-input))

(cl-defun project-shells--project-name ()
  (or project-shells-project-name (funcall project-shells-project-name-func)
      project-shells-empty-project))

(cl-defun project-shells--project-root (proj-name)
  (if (string= proj-name project-shells-empty-project)
      "~/"
    (or project-shells-project-root
	(funcall project-shells-project-root-func))))

(cl-defun project-shells--set-histfile-env (val)
  (when (and project-shells-histfile-env
	     project-shells-histfile-name)
    (setenv project-shells-histfile-env val)))

(cl-defun project-shells--escape-sh (str)
  (replace-regexp-in-string
   "\"" "\\\\\""
   (replace-regexp-in-string "\\\\" "\\\\\\\\" str)))

(cl-defun project-shells--command-string (args)
  (mapconcat
   #'identity
   (cl-loop
    for arg in args
    collect (concat "\"" (project-shells--escape-sh arg) "\""))
   " "))

(cl-defun project-shells--term-command-string ()
  (let* ((prog (or explicit-shell-file-name
		   (getenv "ESHELL") shell-file-name)))
    (concat "exec " (project-shells--command-string
		     (cons prog project-shells-term-args)) "\n")))

(cl-defun project-shells-activate-for-key (key &optional proj proj-root)
  "Create or switch to the shell buffer for the key, the project
name, and the project root directory."
  (let* ((key (replace-regexp-in-string "/" "slash" key))
	 (proj (or proj (project-shells--project-name)))
	 (proj-root (or proj-root (project-shells--project-root proj)))
	 (proj-shells (cdr (assoc proj project-shells-setup)))
	 (shell-info (cdr (assoc key proj-shells)))
	 (name (or (first shell-info) project-shells-default-shell-name))
	 (dir (or (second shell-info) proj-root))
	 (type (or (third shell-info)
		   (if (member key project-shells-term-keys)
		       'term 'shell)))
	 (func (fourth shell-info))
	 (shell-name (format "*%s.%s.%s*" key name proj))
	 (session-dir (expand-file-name (format "%s/%s" proj key)
					project-shells-session-root)))
    (mkdir session-dir t)
    (project-shells--set-histfile-env
     (expand-file-name project-shells-histfile-name session-dir))
    (unwind-protect
	(project-shells--create-switch
	 shell-name dir type
	 (lambda ()
	   (when func
	     (funcall func session-dir))
	   (when (eq type 'term)
	     (term-send-raw-string (project-shells--term-command-string)))
	   (setf project-shells-project-name proj
		 project-shells-project-root proj-root)))
      (project-shells--set-histfile-env nil))))

(cl-defun project-shells-activate (p)
  "Create or switch to the shell buffer for the key just typed"
  (interactive "p")
  (let* ((keys (this-command-keys-vector))
	 (key (seq-subseq keys (1- (seq-length keys))))
	 (key-desc (key-description key)))
    (project-shells-activate-for-key
     key-desc (and (/= p 1) project-shells-empty-project))))

(cl-defun project-shells-setup (map &optional setup)
  "Configure the project shells with the prefix keymap and the
setup, for format of setup, please refer to document of
project-shells-setup."
  (when setup
    (setf project-shells-setup setup))
  (cl-loop
   for key in project-shells-keys
   do (define-key map (kbd key) 'project-shells-activate)))

(provide 'project-shells)

;;; project-shells.el ends here
