package WebService::Simple::Signature;

use Digest::MD5 qw(md5_hex);
use base qw(WebService::Simple);

sub new {
    my $class    = shift;
    my %args     = @_;
    my $sig = delete $args{sig} || "";
    
    my $self = $class->SUPER::new(%args);
    
    my ($sig_name, $secret) = each(%{$sig});
    $self->{sig_name} = $sig_name;
    $self->{secret} = $secret;
    return $self;
}

sub sign_args {
    my ($self, $args) = @_;
    
    my $sig  = $self->{secret};
    foreach my $key (sort {$a cmp $b} keys %{$args}) {
        my $value = (defined($args->{$key})) ? $args->{$key} : "";
        $sig .= $key . $value;
    } 
    warn "sig=" . $sig . "\n" if $self->{debug};
    
    return md5_hex($sig);
}

sub set_signature {
    my ($self, %args) = @_;
    
    my %sig_args = (%{$self->{basic_params}}, %args);
    if(defined $self->{secret} && length $self->{secret}){
        my $sig = $self->sign_args(\%sig_args);
        $args{$self->{sig_name}} = $sig;
    }
    return %args;
}

sub get {
    my $self = shift;
    my ( $url, %extra );
    
    if ( ref $_[0] eq 'HASH' ) {
        $url   = "";
        %extra = %{ shift @_ };
    }
    else {
        $url = shift @_;
        if ( ref $_[0] eq 'HASH' ) {
            %extra = %{ shift @_ };
        }
    }
    
    my @headers = @_;
    my %params = $self->set_signature(%extra);
    return $self->SUPER::get($url, {%params}, @headers);
}

sub post {
    my $self = shift;
    my ( $url, %extra );
    
    if ( ref $_[0] eq 'HASH' ) {
        $url   = "";
        %extra = %{ shift @_ };
    }
    else {
        $url = shift @_;
        if ( ref $_[0] eq 'HASH' ) {
            %extra = %{ shift @_ };
        }
    }
    
    my @headers = @_;
    my %params;
    if(defined $extra{file}){
        my %file = %{$extra{file}};
        delete $extra{file};
        %params = (file => {%file}, $self->set_signature(%extra));
    }else{
        %params = $self->set_signature(%extra);
    }
    return $self->SUPER::post($url, {%params}, @headers);
}

sub request_auth_url {
    my $self = shift;
    my ( $url, %extra );
    
    if ( ref $_[0] eq 'HASH' ) {
        $url   = "";
        %extra = %{ shift @_ };
    }
    else {
        $url = shift @_;
        if ( ref $_[0] eq 'HASH' ) {
            %extra = %{ shift @_ };
        }
    }

    $extra{api_key} = $self->{api_key};
    if(defined $self->{api_secret} && length $self->{api_secret}){
        $extra{api_sig} = $self->sign_args(\%extra);
    }
    my $uri = $self->request_url(
        url        => $self->base_url,
        extra_path => $url,
        params     => {%extra}
    );

    warn "Request URL is $uri\n" if $self->{debug};
    
    return $uri;
}

1;

__END__

=head1 NAME

WebService::Simple::Signature - Simple Interface To Web Services APIs with Flickr like Signature

=head1 SYNOPSIS

  use WebService::Simple::Signature;

  # Simple use case
  my $flickr = WebService::Simple::Signature->new(
      base_url => "http://api.flickr.com/services/",
      param    => { api_key => "your_api_key", auth_token => "got_token"},
      sig => { api_sig => "your_secret_key" }
      );

  # send GET request to 
  # http://api.flickr.com/service/rest/?api_sig=****&auth_token=got_token&api_key=your_api_key&method=flickr.test.echo&name=value
  $flickr->get( 'rest/', { method => "flickr.test.echo", name => "value" } );

  # send POST request to http://api.flickr.com/service/upload/
  # parameter: photo = '~/image.jpg', title = 'title'
  $flickr->post( 'rest/', { title => 'title', file => { photo => '~/image.jpg' } } );

  # To get token:
  my $flickr = WebService::Simple::Signature->new(
      base_url => "http://api.flickr.com/services/",
      param    => { api_key => "your_api_key" },
      sig => { api_sig => "your_secret_key" }
      );
  my $ref = $flickr->get('rest/', {method => 'flickr.auth.getFrob'});
  my $frob = $ref->parse_response->{frob};
  print $flickr->request_auth_url('auth/', {perms => 'write', frob => $frob});
  my $line =<STDIN>;
  ## then access to the URL using your Web Browser and input enter key...
  $ref = $flickr->get('rest/', {method => 'flickr.auth.getToken', 'frob' =>$frob});
  my $token = $ref->parse_response->{auth}->{token};
  print $token . "\n";
  ## this is your token

=head1 AUTHOR

riywo  C<< <riywo.jp@gmail.com> >>

=head1 SEE ALSO

L<WebService::Simple>

=cut
