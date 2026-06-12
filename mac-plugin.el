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
    (remove-hook 'post-command-hook #'atmosphere-update-window-info))

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

(defun mac-plugin-set-trail-decay (fast slow)
  "Set cursor trail decay seconds.
FAST controls the leading corners, SLOW the trailing corners.
Smaller values make the jelly snap back faster.  Kitty defaults: 0.1 / 0.4."
  (interactive "nFast decay (e.g. 0.1): \nnSlow decay (e.g. 0.4): ")
  (swift-set-trail-decay fast slow))

(defun mac-plugin-set-trail-threshold (cells)
  "Set minimum cursor movement (in CELLS, Manhattan distance) to start the trail.
0 disables the threshold so every movement animates."
  (interactive "nThreshold in cells (kitty default 2, 0 disables): ")
  (swift-set-trail-threshold cells))

(defun mac-plugin-test-print-window-info ()
  "Call the swift-test-print-window-info function in Swift to print window information."
  (interactive)
  (let ((x (macos--emacs-point-x))
        (y (macos--emacs-point-y)))
    (swift-test-print-window-info x y)))


;;; Markdown live preview

(defcustom mac-plugin-markdown-preview-idle-delay 0.2
  "Seconds of idle time before the Markdown preview refreshes after an edit."
  :type 'number
  :group 'mac-plugin)

(defcustom mac-plugin-markdown-preview-width 600
  "Width in pixels of the preview pane docked on the right."
  :type 'integer
  :group 'mac-plugin)

(defcustom mac-plugin-markdown-preview-theme "dark"
  "Color theme for the Markdown preview: \"light\" or \"dark\"."
  :type '(choice (const "light") (const "dark"))
  :group 'mac-plugin)

(defvar mac-plugin-markdown--buffer-name " *mac-plugin-markdown-preview*"
  "Name of the placeholder buffer that reserves space for the preview pane.")

(defvar-local mac-plugin-markdown--timer nil
  "Idle timer that debounces preview refreshes for the current buffer.")

(defun mac-plugin-markdown--reserve-space ()
  "Open a blank side window on the right to reserve room for the preview.
Return the actual reserved width in pixels so Swift can match it exactly."
  (let* ((char-width (frame-char-width))
         (columns (max 1 (ceiling (/ (float mac-plugin-markdown-preview-width)
                                     char-width))))
         (buffer (get-buffer-create mac-plugin-markdown--buffer-name))
         (window (display-buffer-in-side-window
                  buffer
                  `((side . right)
                    (slot . 0)
                    (window-width . ,columns)
                    (window-parameters . ((no-other-window . t)
                                          (no-delete-other-windows . t)))))))
    (when window
      ;; Keep the placeholder visually empty.
      (with-current-buffer buffer
        (setq-local mode-line-format nil)
        (setq-local header-line-format nil))
      (set-window-dedicated-p window t)
      ;; Pixel width of the whole window (including fringes/divider) is what the
      ;; WebView should cover on the right edge.
      (window-pixel-width window))))

(defun mac-plugin-markdown--release-space ()
  "Remove the placeholder side window and its buffer."
  (let ((buffer (get-buffer mac-plugin-markdown--buffer-name)))
    (when buffer
      (let ((window (get-buffer-window buffer)))
        (when (window-live-p window)
          (delete-window window)))
      (kill-buffer buffer))))

(defun mac-plugin-markdown--sync-width (&rest _)
  "Resize the native preview pane to match the placeholder side window.
Runs on `window-size-change-functions' so the pane stays aligned as the
frame is resized or toggles native fullscreen."
  (let* ((buffer (get-buffer mac-plugin-markdown--buffer-name))
         (window (and buffer (get-buffer-window buffer))))
    (when (window-live-p window)
      (swift-markdown-preview-set-width (float (window-pixel-width window))))))

(defvar mac-plugin-markdown--scroll-fraction -1.0
  "Last scroll fraction pushed to the preview, to avoid redundant updates.")

(defvar mac-plugin-markdown--source-buffer nil
  "The buffer currently being previewed.")

(defun mac-plugin-markdown--scroll-sync ()
  "Push the source buffer's vertical position to the preview as a fraction.
Maps point's line position within the buffer to a 0..1 fraction; the
preview scrolls to the same fraction of its height.  Not pixel-accurate,
which is fine for a rough follow."
  (when (eq (current-buffer) mac-plugin-markdown--source-buffer)
    (let* ((total (float (max 1 (line-number-at-pos (point-max)))))
           (current (float (line-number-at-pos (point))))
           (fraction (/ (1- current) (max 1.0 (1- total)))))
      ;; Only push when it moved enough to matter (~1%).
      (when (> (abs (- fraction mac-plugin-markdown--scroll-fraction)) 0.01)
        (setq mac-plugin-markdown--scroll-fraction fraction)
        (swift-markdown-preview-scroll fraction)))))

(defun mac-plugin-markdown--buffer-string ()
  "Return the current buffer's contents as a string for previewing."
  (buffer-substring-no-properties (point-min) (point-max)))

(defun mac-plugin-markdown--refresh ()
  "Push the current buffer's contents into the preview pane."
  (when (buffer-live-p (current-buffer))
    (swift-markdown-preview-update (mac-plugin-markdown--buffer-string))))

(defun mac-plugin-markdown--schedule-refresh (&rest _)
  "Debounced refresh hook for `after-change-functions'.
Cancels any pending timer and reschedules a refresh after
`mac-plugin-markdown-preview-idle-delay' seconds of idle time."
  (when mac-plugin-markdown--timer
    (cancel-timer mac-plugin-markdown--timer))
  (let ((buffer (current-buffer)))
    (setq mac-plugin-markdown--timer
          (run-with-idle-timer
           mac-plugin-markdown-preview-idle-delay nil
           (lambda ()
             (when (buffer-live-p buffer)
               (with-current-buffer buffer
                 (mac-plugin-markdown--refresh))))))))

(defun mac-plugin-markdown-preview ()
  "Open a live Markdown preview of the current buffer, docked on the right.
Emacs reserves a blank side window on the right and the native preview
pane is drawn over it, so it adapts to any window size including native
fullscreen. The preview refreshes automatically as you edit."
  (interactive)
  (let ((width (or (mac-plugin-markdown--reserve-space)
                   mac-plugin-markdown-preview-width)))
    (setq mac-plugin-markdown--source-buffer (current-buffer))
    (setq mac-plugin-markdown--scroll-fraction -1.0)
    (swift-markdown-preview-set-theme mac-plugin-markdown-preview-theme)
    (swift-markdown-preview-set-width (float width))
    (swift-markdown-preview-open (mac-plugin-markdown--buffer-string)))
  (add-hook 'after-change-functions #'mac-plugin-markdown--schedule-refresh nil t)
  (add-hook 'window-size-change-functions #'mac-plugin-markdown--sync-width)
  (add-hook 'post-command-hook #'mac-plugin-markdown--scroll-sync))

(defun mac-plugin-markdown-preview-stop ()
  "Close the Markdown preview pane and stop refreshing."
  (interactive)
  (remove-hook 'after-change-functions #'mac-plugin-markdown--schedule-refresh t)
  (remove-hook 'window-size-change-functions #'mac-plugin-markdown--sync-width)
  (remove-hook 'post-command-hook #'mac-plugin-markdown--scroll-sync)
  (setq mac-plugin-markdown--source-buffer nil)
  (when mac-plugin-markdown--timer
    (cancel-timer mac-plugin-markdown--timer)
    (setq mac-plugin-markdown--timer nil))
  (swift-markdown-preview-close)
  (mac-plugin-markdown--release-space))

(define-minor-mode mac-plugin-markdown-preview-mode
  "Toggle live native Markdown preview for the current buffer."
  :lighter " MdPrev"
  (if mac-plugin-markdown-preview-mode
      (mac-plugin-markdown-preview)
    (mac-plugin-markdown-preview-stop)))


(provide 'mac-plugin)
;;; mac-plugin.el ends here
