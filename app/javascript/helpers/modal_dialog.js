import { Controller } from "@hotwired/stimulus"
import { lockScroll, unlockScroll } from "helpers/scroll_lock"

// Shared <dialog> lifecycle for the drive-detail and day-summary modals: both sit
// on <body>, are populated client-side from the clicked element's data
// attributes, and need identical open/close/backdrop/scroll-lock behaviour.
// Subclasses implement `open(event)` — populate from the event, then call
// `showDialog()`.
//
// Lives under helpers/ rather than controllers/ so eagerLoadControllersFrom does
// not register the base class as a controller in its own right.
export class ModalDialogController extends Controller {
  static targets = ["dialog"]

  // Turbo snapshots the DOM for its cache with the `open` attribute still set,
  // and a dialog's top-layer membership is not serializable — so a restored
  // snapshot holds a dialog that is open but NOT modal: no backdrop, Escape
  // inert, the whole page live behind it. Reconnecting is the first moment we
  // can see that state, so close it here. close() also fires the `close` event,
  // which releases the scroll lock the snapshot may have been cached with.
  connect() {
    // The controller sits on <body>, but the dialog partial only renders for a
    // signed-in user — so on the sign-in and marketing pages there is no target
    // and reaching for one throws during connect.
    if (!this.hasDialogTarget) return

    // removeAttribute rather than close(): close() fires its event asynchronously,
    // and a late handler would release a lock a subsequent open has already taken.
    // The class suppresses the exit transition for this one removal — the dialog
    // was never really open, so animating it out would flash a ghost modal over
    // the restored page.
    const dialog = this.dialogTarget
    dialog.classList.add("is-restoring")
    dialog.removeAttribute("open")
    // Forces the style flush that commits the removal above while the class is
    // still applied. Without this read both changes land in one recalc, the
    // transition is never suppressed, and the ghost fades in view.
    getComputedStyle(dialog).opacity
    dialog.classList.remove("is-restoring")
    unlockScroll(this)
  }

  showDialog() {
    // Guard on :modal, not .open. Turbo caches the DOM with the `open` attribute
    // still set, and top-layer membership does not survive that round trip — so a
    // restored snapshot can hold a dialog that is open but not modal, with no
    // backdrop and a live page behind it. Re-show those instead of treating them
    // as already open.
    if (this.dialogTarget.matches(":modal")) return
    // Same reason as connect(): clearing the attribute cannot queue a close event
    // that lands after the lockScroll below and undoes it.
    this.dialogTarget.removeAttribute("open")

    // Native showModal() does not stop the page behind the backdrop from
    // scrolling, so take the lock ourselves; onClose gives it back.
    lockScroll(this)
    this.dialogTarget.showModal()
  }

  // Button and backdrop paths: release the lock synchronously here rather than
  // leaning on the dialog's `close` event, which doesn't fire reliably.
  close() {
    unlockScroll(this)
    this.dialogTarget.close()
  }

  // Escape closes the dialog natively (firing cancel/close); this releases the
  // lock for that path.
  onClose() {
    // A queued close event can land after the dialog has been re-shown, so check
    // the dialog really is closed before giving the lock back.
    if (!this.dialogTarget.matches(":modal")) unlockScroll(this)
  }

  disconnect() {
    unlockScroll(this)
  }

  // Native <dialog> click lands on the dialog element itself when the backdrop
  // (outside the card) is clicked.
  backdropClick(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
