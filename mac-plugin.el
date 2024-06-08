;;; mac-plugin.el --- Insert description here -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(defvar macos-lib-name "libEmacsMacPluginModule.dylib")

(defun macos-module-dev-reload ()
  "Rebuild and reload native module."
  (interactive)
  (compile (format "swift build && %s -ne '(module-load \"%s\")'"
                   (executable-find "emacsclient")
                   (macos--built-module-path))))

(defun macos--module-source-root ()
  "Return the source root directory for the native module."
  (let ((project-root (expand-file-name (locate-dominating-file default-directory "Package.swift"))))
    (unless project-root
      (error "Not in macos project"))
    (unless (file-exists-p (file-name-concat project-root "mac-plugin.el"))
      (error "Not in macos project"))
    project-root))

(defun macos--built-module-path ()
  "Return the path to the built module."
  (file-name-concat (macos--module-source-root) ".build" "debug" macos-lib-name))

(defun atmosphere-enable ()
  "Enable monitoring of cursor and frame changes."
  (interactive)
  (add-hook 'post-command-hook #'update-window-info))

(defun macos--emacs-point-x ()
  "Return the x coordinate at point, adjusted for visual modes like Olivetti."
  (let ((pos (window-absolute-pixel-position)))
    (car pos)))

(defun macos--emacs-point-y ()
  "Return the y coordinate at point, adjusted for visual modes like Olivetti."
  (let ((pos (window-absolute-pixel-position)))
    (cdr pos)))

(defun emacs-cursor-width ()
  "Return the approximate cursor width in pixels."
  (let ((char-width (frame-char-width)))
    ;; You might adjust this depending on your cursor type.
    char-width))

(defun emacs-cursor-height ()
  "Return the cursor height in pixels."
  (let ((char-height (frame-char-height)))
    ;; This returns the height of a character cell. Adjust if your cursor is a bar.
    char-height))

(defun clear-window-info ()
  "Clear the window information."
    (interactive)
  (macos-module--clear-window-info))

(defun update-window-info ()
  "Update the window information."
  (interactive)
  (let (
        (model (swift-create-window-info))
        (x (macos--emacs-point-x))
        (y (macos--emacs-point-y))
        (cursor-width (emacs-cursor-width))
        (cursor-height (emacs-cursor-height)))
    ;; (message "Debug: x=%s, y=%s, width=%d, height=%d" x y cursor-width cursor-height) ; Debug output
    (swift-set-window-info-x model x)
    (swift-set-window-info-y model y)
    (swift-set-window-info-width model cursor-width)
    (swift-set-window-info-height model cursor-height)
    (macos-module--update-window-info model)))



(provide 'mac-plugin)
;;; mac-plugin.el ends here
