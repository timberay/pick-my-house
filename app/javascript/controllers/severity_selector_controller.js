import { Controller } from "@hotwired/stimulus"

// Auto-submits the severity form when a severity button is clicked.
// The native submit-on-click behaviour is sufficient; this controller
// exists to mark pressed state before the server round-trip so mobile
// users see instant feedback if network is slow.
export default class extends Controller {
  static targets = ["form"]

  connect() {
    this.element.querySelectorAll("button[aria-pressed]").forEach((btn) => {
      btn.addEventListener("click", () => {
        this.element.querySelectorAll("button[aria-pressed]").forEach((b) => b.setAttribute("aria-pressed", "false"))
        btn.setAttribute("aria-pressed", "true")
      })
    })
  }
}
