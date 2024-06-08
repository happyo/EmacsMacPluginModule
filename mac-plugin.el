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
    (unless (file-exists-p (file-name-concat project-root "macos.el"))
      (error "Not in macos project"))
    project-root))

(defun macos--built-module-path ()
  "Return the path to the built module."
  (file-name-concat (macos--module-source-root) ".build" "debug" macos-lib-name))

(defun atmosphere-enable ()
  "Enable monitoring of cursor and frame changes."
  (interactive)
  (add-hook 'post-command-hook #'update-window-info))

(defun update-window-info ()
  "Update the window information."
  (interactive)
  (let ((x (macos--emacs-point-x))
        (y (macos--emacs-point-y)))
    (macos-module--update-window-info x y)))


(provide 'mac-plugin)
;;; mac-plugin.el ends here
