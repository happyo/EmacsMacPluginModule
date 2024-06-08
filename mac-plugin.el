;;; mac-plugin.el --- Insert description here -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(defgroup mac-plugin nil
  "Customization options for mac-plugin."
  :group 'external)

(defcustom macos-project-root "~/.emacs.d/site-lisp/EmacsMacPluginModule"
  "The root directory of the macOS project."
  :type 'string
  :group 'mac-plugin)

(defvar macos-lib-name "libEmacsMacPluginModule.dylib")

(defun macos-module-dev-reload ()
  "Rebuild and reload native module."
  (interactive)
  (compile (format "swift build && %s -ne '(module-load \"%s\")'"
                   (executable-find "emacsclient")
                   (macos--built-module-path))))

(defun macos-module-build-release ()
  "Rebuild and reload native module."
  (interactive)
  (compile (format "swift build -c release && %s -ne '(module-load \"%s\")'"
                   (executable-find "emacsclient")
                   (macos--built-release-path))))

(defun macos--built-module-path ()
  "Return the path to the built module."
  (expand-file-name (file-name-concat macos-project-root ".build" "debug" macos-lib-name)))

(defun macos--built-release-path ()
  "Return the path to the built module."
  (expand-file-name (file-name-concat macos-project-root ".build" "release" macos-lib-name)))

(defun atmosphere-enable ()
  "Enable monitoring of cursor and frame changes."
  (interactive)
  (add-hook 'post-command-hook #'update-window-info))

(defun atmosphere-disable ()
    "Disable monitoring of cursor and frame changes."
    (interactive)
    (clear-window-info)
    (remove-hook 'post-command-hook #'update-window-info))

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
  (macos-module--clear-window-info))

(defun update-window-info ()
  "Update the window information."
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

(defun mac-plugin-load-release ()
  "Load the macOS native module in release mode."
  (let ((module-path (macos--built-release-path)))
    (unless (file-exists-p module-path)
      (error "Module file %s does not exist" module-path))
    (module-load module-path)))

(provide 'mac-plugin)
;;; mac-plugin.el ends here
