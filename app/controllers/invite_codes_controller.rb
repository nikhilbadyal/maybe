class InviteCodesController < ApplicationController
  before_action :ensure_self_hosted

  def index
    @invite_codes = InviteCode.all
  end

  def create
    raise StandardError, "You are not allowed to generate invite codes" unless Current.user.admin?
    InviteCode.generate!
    redirect_back_or_to invite_codes_path, notice: "Code generated"
  end

  def destroy
    raise StandardError, "You are not allowed to delete invite codes" unless Current.user.admin?

    code = InviteCode.find(params[:id])

    if code.destroy
      flash[:notice] = "Code deleted"
    else
      flash[:alert] = "Failed to delete invite code"
    end

    redirect_back_or_to invite_codes_path
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Invite code not found"
    redirect_back_or_to invite_codes_path
  end

  private

    def ensure_self_hosted
      redirect_to root_path unless self_hosted?
    end
end
