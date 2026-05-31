import { Controller } from "@hotwired/stimulus";

// Stimulus controller to manage multi-select dropdown UI states.
// It dynamically updates the visual label (the list of checked options)
// as checkboxes are selected/deselected, avoiding inline javascript.
export default class extends Controller {
  // Targets required for checkboxes, summary labels, and closing the details menu
  static targets = ["checkbox", "label", "details"];

  connect() {
    // Initial update to display currently selected tags when the page loads
    this.updateLabel();

    // Bind click outside event handler to close the dropdown when clicking elsewhere
    this.clickOutsideHandler = this.clickOutside.bind(this);
    document.addEventListener("click", this.clickOutsideHandler);
  }

  disconnect() {
    // Clean up click outside event listener on controller teardown to prevent memory leaks
    document.removeEventListener("click", this.clickOutsideHandler);
  }

  // Iterates over all tag checkboxes, filters the checked ones,
  // maps them to their adjacent text label, and joins them with commas.
  updateLabel() {
    const selected = Array.from(this.checkboxTargets)
      .filter(checkbox => checkbox.checked)
      .map(checkbox => checkbox.nextElementSibling.textContent.trim());

    this.labelTarget.textContent = selected.length > 0 ? selected.join(", ") : "(none)";
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
