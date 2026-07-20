import { Controller } from "@hotwired/stimulus"
import { hasHover } from "helpers/device"

// Connects to data-controller="export"
//
// Progressive enhancement for the CSV export links. On a touch device — or any
// chrome-less standalone install — that can share a file, intercept the click
// and hand the CSV to the native share sheet: an overlay that returns the user
// to the app, instead of the chrome-less download view that traps iOS standalone
// users. On a desktop browser, or where file sharing is unsupported, we never
// preventDefault, so the link falls through to a normal browser download.
export default class extends Controller {
  share(event) {
    // Probe with an empty file — canShare validates the type, not the bytes.
    const probe = new File([""], "probe.csv", { type: "text/csv" })
    if (!navigator.canShare?.({ files: [probe] })) return

    // A hover-capable pointer means a desktop browser, where the download works
    // and the share sheet is unwanted friction. A standalone install is still
    // chrome-less even with a pointer attached (e.g. iPad + trackpad), so it
    // always takes the share path.
    if (hasHover() && !this.standalone) return

    event.preventDefault()
    if (this.sharing) return // swallow repeat taps while a share is already in flight
    this.sharing = true
    this.shareCsv(this.element.href).finally(() => { this.sharing = false })
  }

  async shareCsv(url) {
    const busyTimer = setTimeout(() => this.notify("Preparing your export…"), 400)
    try {
      const response = await fetch(url, { headers: { Accept: "text/csv" } })
      // An expired session redirects to a 200 HTML login page; only sharing a
      // real CSV keeps us from packaging that HTML as driving-log.csv.
      if (!response.ok || !this.isCsv(response)) {
        throw new Error(`Export request failed: ${response.status} ${response.headers.get("Content-Type")}`)
      }

      const blob = await response.blob()
      const file = new File([blob], this.filenameFrom(response), { type: "text/csv" })
      // Stop the busy indicator before opening the share sheet: navigator.share
      // stays pending the whole time the sheet is up, so a still-armed timer
      // would flash "Preparing…" behind it on essentially every share.
      clearTimeout(busyTimer)
      await navigator.share({ files: [file], title: "Drive50 Log" })
    } catch (error) {
      if (error.name === "AbortError") return // user dismissed the share sheet
      this.handleFailure(url)
    } finally {
      clearTimeout(busyTimer)
    }
  }

  // Navigating to the CSV is a safe download in a normal browser tab, but in a
  // standalone PWA it drops the user into the chrome-less view we're avoiding —
  // so there we surface an error and let them retry instead.
  handleFailure(url) {
    if (this.standalone) {
      this.notify("Couldn't prepare your export. Please try again.", { type: "error", duration: 5000 })
    } else {
      window.location.href = url
    }
  }

  get standalone() {
    return window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true
  }

  isCsv(response) {
    return (response.headers.get("Content-Type") || "").includes("csv")
  }

  filenameFrom(response) {
    const disposition = response.headers.get("Content-Disposition") || ""
    return disposition.match(/filename="?([^"]+)"?/)?.[1] || "driving-log.csv"
  }

  notify(message, { type = "success", duration = 2000 } = {}) {
    const container = document.getElementById("toast-container")
    const template = document.getElementById("toast-template")
    if (!container || !template) return

    const fragment = template.content.cloneNode(true)
    const toast = fragment.querySelector(".toast")
    toast.classList.remove("toast-success")
    toast.classList.add(`toast-${type}`)
    toast.dataset.toastTypeValue = type
    toast.dataset.toastDurationValue = duration
    fragment.querySelector(".toast-content").textContent = message
    container.appendChild(fragment)
  }
}
