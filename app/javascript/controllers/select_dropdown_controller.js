import { Controller } from "@hotwired/stimulus";

// Stimulus controller to manage custom single-select dropdown UI states.
// It maps standard HTML `<details>` and `<summary>` elements with radio button inputs.
// This allows custom styled lists that behave identically to native `<select>` fields
// but are immune to mobile viewport coordinate/overlay rendering bugs.
export default class extends Controller {
  // Targets required for reading radio values, updating display label, and closing details
  static targets = ["radio", "label", "details"];

  connect() {
    // Initial update to synchronize the visual label with the pre-selected option when loading
    this.updateLabel();
    
    // Bind click outside event handler to close the dropdown when clicking elsewhere
    this.clickOutsideHandler = this.clickOutside.bind(this);
    document.addEventListener("click", this.clickOutsideHandler);
  }

  disconnect() {
    // Clean up click outside event listener on controller teardown to prevent memory leaks
    document.removeEventListener("click", this.clickOutsideHandler);
  }

  // Update visual text inside the summary tag matching the checked radio option
  updateLabel() {
    // Find the currently checked radio input target
    const checkedRadio = this.radioTargets.find(radio => radio.checked);
    if (checkedRadio) {
      // Use the text content of the sibling span as the display name
      const textSpan = checkedRadio.nextElementSibling;
      this.labelTarget.textContent = textSpan ? textSpan.textContent.trim() : "(none)";
    } else {
      // Default fallback label if no option is selected
      this.labelTarget.textContent = "(none)";
    }
  }

  // Triggered when any radio option is selected/changed
  select(event) {
    // Refresh visual summary label
    this.updateLabel();
    // Auto-close dropdown details immediately on selection
    this.close();
  }

  // Closes the dropdown details container by removing the 'open' attribute
  close() {
    if (this.hasDetailsTarget) {
      this.detailsTarget.removeAttribute("open");
    }
  }

  // Closes the dropdown details container if a click event originates from outside this element
  clickOutside(event) {
    if (this.hasDetailsTarget && this.detailsTarget.hasAttribute("open") && !this.element.contains(event.target)) {
      this.close();
    }
  }
}
