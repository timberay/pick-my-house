import { Controller } from "@hotwired/stimulus"

// Native <details> handles the open/close state.
// This controller is a no-op placeholder for future enhancement;
// it ensures data-controller="memo-toggle" does not throw.
export default class extends Controller {
  static targets = ["panel"]
}
