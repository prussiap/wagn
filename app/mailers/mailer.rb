# -*- encoding : utf-8 -*-
require 'open-uri'

class Mailer < ActionMailer::Base
  @@email_defaults = Wagn::Conf[:email_defaults] || {}
  @@email_defaults.symbolize_keys!
  @@email_defaults[:return_path] ||= @@email_defaults[:from] if @@email_defaults[:from]
  default @@email_defaults
  
  include LocationHelper
  def account_info(user, subject, message)
    url_key = user.card.cardname.to_url_key
    @email    = (user.email    or raise Wagn::Oops.new("Oops didn't have user email"))
    @password = (user.password or raise Wagn::Oops.new("Oops didn't have user password"))
    @card_url = wagn_url user.card
    @pw_url   = wagn_url "/card/options/#{url_key}"
    @login_url= wagn_url "/account/signin"
    @message  = message.clone

    args =  { :to => @email, :subject  => subject }
    set_from_args args, ( Card.setting('*invite+*from') || begin
      curr = User.current_user
      from_user = curr.anonymous? || curr.id == user.id ? User[:wagbot] : curr
      from_user.card ? "#{from_user.card.name} <#{from_user.email}>" : '' #how could there not be a card??
    end ) #FIXME - might want different from settings for different contexts?
    mail args
  end                 
  
  def signup_alert invite_request
    @site = Card.setting('*title')
    @card = invite_request
    @email= invite_request.extension.email
    @name = invite_request.name
    @content = invite_request.content
    @request_url  = wagn_url invite_request
    @requests_url = wagn_url Card['Account Request']

    args = { 
      :to           => Card.setting('*request+*to'),
      :subject      => "#{invite_request.name} signed up for #{@site}",
      :content_type => 'text/html',
    }
    set_from_args args, Card.setting('*request+*from') || "#{@name} <#{@email}"
    mail args
  end               

  
  def change_notice user, card, action, watched, subedits=[], updated_card=nil
    #warn "change_notice( #{user}, #{card.inspect}, #{action}, #{watched} ...)"
    updated_card ||= card
    @card = card
    @updater = updated_card.updater.card.name
    @action = action
    @subedits = subedits
    @card_url = wagn_url card
    @change_url = wagn_url "/card/changes/#{card.cardname.to_url_key}"
    @unwatch_url = wagn_url "/card/watch/#{watched.to_cardname.to_url_key}?toggle=off"
    @udpater_url = wagn_url card.updater.card
    @watched = (watched == card.cardname ? "#{watched}" : "#{watched} cards")

    args = {
      :to           => "#{user.email}",
      :subject      => "[#{Card.setting('*title')} notice] #{@updater} #{action} \"#{card.name}\"" ,
      :content_type => 'text/html',
    }
    set_from_args args, User[:wagbot].email    
    mail args
  end
  
  def flexmail config
    @message = config.delete(:message)
    
    if attachment_list = config.delete(:attach) and !attachment_list.empty?
      attachment_list.each_with_index do |cardname, i|
        if c = Card[ cardname ] and c.respond_to?(:attach) 
          attachments["attachment-#{i + 1}.#{c.attach_extension}"] = File.read( c.attach.path )
        end
      end
    end
    
    set_from_args config, config[:from]
    mail config
  end
  
  private
  
  def set_from_args args, from
    from_name, from_email = parse_address( from )
    if default_from=@@email_defaults[:from]
      args[:from] = !from_email ? default_from : "#{from_name || from_email} <#{default_from}>"
      args[:reply_to] ||= from
    else
      args[:from] = from
    end
  end
  
  def parse_address addr
    name, email = (addr =~ /(.*)\<(.*)>/) ? [$1.strip, $2] : [nil, addr]
  end
  
end

