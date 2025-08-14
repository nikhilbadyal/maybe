import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["select", "customDateInputs", "startDate", "endDate"]; 

  connect() {
    this.#syncVisibility();
  }

  toggleDateInputs() {
    this.#syncVisibility();
    if (this.selectTarget.value !== "custom") {
      // Submit immediately for non-custom periods
      this.element.requestSubmit();
    }
  }

  submitForm() {
    // Only used when we explicitly call it (we no longer auto-submit on date change)
    if (this.selectTarget.value === "custom") {
      if (this.hasStartDateTarget && this.hasEndDateTarget) {
        const start = this.startDateTarget.value;
        const end = this.endDateTarget.value;
        const invalid = !start || !end || new Date(start) > new Date(end);
        this.#setInvalid(this.startDateTarget, !start);
        this.#setInvalid(this.endDateTarget, !end || (start && new Date(start) > new Date(end)));
        if (invalid) return;
      }
    }
    this.element.requestSubmit();
  }

  #syncVisibility() {
    const isCustom = this.selectTarget.value === "custom";
    this.customDateInputsTarget.classList.toggle("hidden", !isCustom);
    this.#setCustomEnabled(isCustom);
  }

  #setCustomEnabled(enabled) {
    if (this.hasStartDateTarget) {
      this.startDateTarget.disabled = !enabled;
      if (enabled) {
        this.startDateTarget.setAttribute("name", "start_date");
      } else {
        this.startDateTarget.removeAttribute("name");
      }
    }
    if (this.hasEndDateTarget) {
      this.endDateTarget.disabled = !enabled;
      if (enabled) {
        this.endDateTarget.setAttribute("name", "end_date");
      } else {
        this.endDateTarget.removeAttribute("name");
      }
    }
  }

  #setInvalid(input, isInvalid) {
    if (!input) return;
    input.classList.toggle("border-destructive", isInvalid);
    input.classList.toggle("border-secondary", !isInvalid);
  }
}


