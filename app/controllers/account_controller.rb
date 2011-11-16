class InvitationError < StandardError; end

class AccountController < ApplicationController
  before_filter :login_required, :only => [ :invite, :update ]
  helper :wagn

  def signup
    raise(Wagn::Oops, "You have to sign out before signing up for a new Account") if logged_in?  #ENGLISH
    raise(Wagn::PermissionDenied, "Sorry, no Signup allowed") unless Card.new(:typecode=>'InvitationRequest').ok? :create #ENGLISH

    user_args = (params[:user]||{}).merge(:status=>'pending').symbolize_keys
    @user = User.new( user_args ) #does not validate password
    card_args = (params[:card]||{}).merge(:typecode=>'InvitationRequest')
    @card = Card.new( card_args )

    return unless request.post?
    return unless (captcha_required? && ENV['RECAPTCHA_PUBLIC_KEY'] ? verify_captcha(:model=>@user) : true)

    return unless @user.errors.empty?
    @user, @card = User.create_with_card( user_args, card_args )
    return unless @user.errors.empty?

    if System.ok?(:create_accounts)       #complete the signup now
      email_args = { :message => System.setting('*signup+*message') || "Thanks for signing up to #{System.site_title}!",  #ENGLISH
                     :subject => System.setting('*signup+*subject') || "Account info for #{System.site_title}!" }  #ENGLISH
      @user.accept(email_args)
      redirect_to System.path_setting(System.setting('*signup+*thanks'))
    else
      User.as :wagbot do
        Mailer.signup_alert(@card).deliver if System.setting('*request+*to')
      end
      redirect_to System.path_setting(System.setting('*request+*thanks'))
    end
  end



  def accept
    raise(Wagn::Oops, "I don't understand whom to accept") unless params[:card]
    @card = Card[params[:card][:key]] or raise(Wagn::NotFound, "Can't find this Account Request")  #ENGLISH
    @user = @card.extension or raise(Wagn::Oops, "This card doesn't have an account to approve")  #ENGLISH
    System.ok?(:create_accounts) or raise(Wagn::PermissionDenied, "You need permission to create accounts")  #ENGLISH

    if request.post?
      @user.accept(params[:email])
      if @user.errors.empty? #SUCCESS
        redirect_to System.path_setting(System.setting('*invite+*thanks'))
        return
      end
    end
    render :action=>'invite'
  end

  def invite
    System.ok?(:create_accounts) or raise(Wagn::PermissionDenied, "You need permission to create")  #ENGLISH

    @user, @card = request.post? ?
      User.create_with_card( params[:user], params[:card] ) :
      [User.new, Card.new()]
    if request.post? and @user.errors.empty?
      @user.send_account_info(params[:email])
      redirect_to System.path_setting(System.setting('*invite+*thanks'))
    end
  end


  def signin
    Rails.logger.info "~~~~~~~~~~~~~signing in"
    if params[:login]
      password_authentication(params[:login], params[:password])
    end
    Rails.logger.info  "signed in? #{session.inspect}"
  end

  def signout
    self.current_user = nil
    flash[:notice] = "You have been logged out." #ENGLISH
    redirect_to System.path_setting('/')  # previous_location here can cause infinite loop.  ##  Really?  Shouldn't.  -efm
  end

  def forgot_password
    return unless request.post?
    @user = User.find_by_email(params[:email].downcase)
    if @user.nil?
      flash[:notice] = "Could not find a user with that email address."   #ENGLISH
      render :action=>'signin', :status=>404
    elsif !@user.active?
      flash[:notice] = "The account associated with that email address is not active."  #ENGLISH
      render :action=>'signin', :status=>403
    else
      @user.generate_password
      @user.save!
      subject = "Password Reset"  #ENGLISH
      message = "You have been given a new temporary password.  " +  #ENGLISH
         "Please update your password once you've logged in. "
      Mailer.account_info(@user, subject, message).deliver
      flash[:notice] = "A new temporary password has been set on your account and sent to your email address"  #ENGLISH
      redirect_to previous_location
    end
  end

  def update
    load_card
    @user = @card.extension or raise("extension gotta be a user")    #ENGLISH
    element_id = params[:element]

    if @user.update_attributes params[:user]
      render :update do |page|
        page.wagn.card.find("#{element_id}").continue_save()
      end
    else
      error_message = render_to_string :inline=>'<%= error_messages_for @user %>'
      render :update do |page|
        page.wagn.messenger.note "Update user failed" + error_message  #ENGLISH

      end
    end
  end

#  def deny_all  ## DEPRECATED:  this method will not be long for this world.
#    if System.ok?(:administrate_users)
#      Card::InvitationRequest.find_all_by_trash(false).each do |card|
#        card.destroy
#      end
#      redirect_to System.path_setting('/wagn/Account_Request')
#    end
#  end
#
#  def empty_trash ## DEPRECATED:  this method will not be long for this world.
#    if System.ok?(:administrate_users)
#      User.find_all_by_status('blocked').each do |user|
#        card=Card.find_by_extension_type_and_extension_id('User',user.id)
#        user.destroy                if (!card or card.trash)
#        card.destroy_without_trash  if (card and card.trash)
#      end
#      redirect_to System.path_setting('/wagn/Account_Request')
#    end
#  end

  protected
  
  def password_authentication(login, password)
    if self.current_user = User.authenticate(params[:login], params[:password])
      Rails.logger.info "successful_login!!!"
      successful_login
    elsif u = User.find_by_email(params[:login].strip.downcase)
      if u.blocked?
        failed_login("Sorry, this account is currently blocked.")  #ENGLISH
      else
        failed_login("Wrong password for that email")  #ENGLISH
      end
    else
      failed_login("We don't recognize that email")  #ENGLISH
    end
    Rails.logger.info "finished pw auth"
  end



  private

    def successful_login
      flash[:notice] = "Welcome to #{System.site_title}"  #ENGLISH
      redirect_to previous_location
    end

    def failed_login(message)
      raise message
      flash[:warning] = message
      render :action=>'signin', :status=>403
    end

end
