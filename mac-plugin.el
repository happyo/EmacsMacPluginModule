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

(defcustom mac-plugin-cursor-block-commands '("watch-other-window-up" "watch-other-window-down" "self-insert-command")
  "Cursor animation is disabled if the current command matches `mac-plugin-cursor-block-commands'."
  :type 'list)

(defvar macos-lib-name "libEmacsMacPluginModule.dylib")

(defun macos-module-dev-reload ()
  "Rebuild and reload native module."
  (interactive)
  (let ((default-directory macos-project-root))
    (compile (format "swift build && %s -ne '(module-load \"%s\")'"
                     (executable-find "emacsclient")
                     (macos--built-module-path)))))

(defun macos-module-build-release ()
  "Rebuild and reload native module."
  (interactive)
  (let ((default-directory macos-project-root))
    (compile (format "swift build -c release && %s -ne '(module-load \"%s\")'"
                     (executable-find "emacsclient")
                     (macos--built-release-path)))))

(defun macos--built-module-path ()
  "Return the path to the built module."
  (expand-file-name (file-name-concat macos-project-root ".build" "debug" macos-lib-name)))

(defun macos--built-release-path ()
  "Return the path to the built module."
  (expand-file-name (file-name-concat macos-project-root ".build" "release" macos-lib-name)))

(defun mac-plugin-cursor-is-block-command-p ()
  (member (format "%s" this-command) mac-plugin-cursor-block-commands))

(defun atmosphere-update-window-info ()
  "Update window information unless inserting text."
  (unless (mac-plugin-cursor-is-block-command-p)
    (update-window-info)))

(defun atmosphere-enable ()
  "Enable monitoring of cursor movements and other changes, but not text insertion."
  (interactive)
  (add-hook 'post-command-hook #'atmosphere-update-window-info))

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

(defun mac-plugin-set-cursor-color (color)
  "Set the cursor color to COLOR."
  (interactive "sEnter cursor color (hex): ")
  (swift-set-cursor-color color))

(defun mac-plugin-set-shadow-opacity (opacity)
  "Set the shadow opacity to OPACITY."
  (interactive "nEnter shadow opacity (0.0 to 1.0): ")
  (swift-set-shadow-opacity opacity))

(defun mac-plugin-test-print-window-info ()
  "Call the swift-test-print-window-info function in Swift to print window information."
  (interactive)
  (let ((x (macos--emacs-point-x))
        (y (macos--emacs-point-y)))
    (swift-test-print-window-info x y)))

(defun mac-plugin-test-add-search-bar ()
  "Call the swift-test-add-search-bar function in Swift to add a search bar."
  (interactive)
  (swift-search-add-bar))

(provide 'mac-plugin)
;;; mac-plugin.el ends here
