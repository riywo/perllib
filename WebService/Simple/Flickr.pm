package WebService::Simple::Flickr;

use base qw(WebService::Simple::Signature);
__PACKAGE__->config(
    base_url   => "http://api.flickr.com/services/",
    upload_url   => "http://api.flickr.com/services/upload/",
    );

sub new {
    my $class    = shift;
    my %args     = @_;
    my $api_key = delete $args{api_key} || "";
    my $api_secret = delete $args{api_secret} || "";
    my $auth_token = delete $args{auth_token} || "";
    
    my $self = $class->SUPER::new(%args);
    $self->{api_key} = $api_key;
    $self->{api_secret} = $api_secret;
    $self->{auth_token} = $auth_token;
    return $self;
}

sub api_key { $_[0]->{api_key} }
sub api_secret { $_[0]->{api_secret} }
sub auth_token { $_[0]->{auth_token} }

sub sign_args {
    my ($self, $args) = @_;
    
    my $sig  = $self->api_secret;
    foreach my $key (sort {$a cmp $b} keys %{$args}) {
        my $value = (defined($args->{$key})) ? $args->{$key} : "";
        $sig .= $key . $value;
    } 
    warn "sig=" . $sig . "\n" if $self->{debug};
    
    return md5_hex($sig);
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
    
    $extra{api_key} = $self->{api_key};
    %extra = (%{$self->{basic_params}}, %extra);
    if(defined $self->{api_secret} && length $self->{api_secret}){
        if(defined $self->{auth_token} && length $self->{auth_token}){
            $extra{auth_token} = $self->{auth_token};
        }
        $extra{api_sig} = $self->sign_args(\%extra);
    }
    
    my @headers = @_;
    return $self->SUPER::get($url, {%extra}, @headers);
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
    
    $extra{api_key} = $self->{api_key};
    my $photo = delete $extra{photo};
    %extra = (%{$self->{basic_params}}, %extra);
    if(defined $self->{api_secret} && length $self->{api_secret}){
        if(defined $self->{auth_token} && length $self->{auth_token}){
            $extra{auth_token} = $self->{auth_token};
        }
        $extra{api_sig} = $self->sign_args(\%extra);
    }
    
    my @headers = @_;
    $extra{photo} = [$photo] if ref $photo ne "ARRAY";
    return $self->SUPER::post($url, {%extra}, @headers);
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
