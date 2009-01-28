package WebService::Simple::Flickr;

use Digest::MD5 qw(md5_hex);

use base qw(WebService::Simple);
__PACKAGE__->config(
    base_url   => "http://api.flickr.com/services/rest/",
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
    print "sig=" . $sig . "\n";
    return md5_hex($sig);
}

sub get {
    my ($self, $args) = @_;
    $args->{api_key} = $self->{api_key};

    if(defined $self->{api_secret} && length $self->{api_secret}){
        if(defined $self->{auth_token} && length $self->{auth_token}){
            $args->{auth_token} = $self->{auth_token};
        }
        $args->{api_sig} = $self->sign_args($args);
    }
    return $self->SUPER::get($args);
}

sub upload_post {
    my ($self, $args) = @_;
    $args->{api_key} = $self->{api_key};
    local $self->{base_url} = $self->config->{upload_url};

    my $photo = delete $args->{photo};
    
    if(defined $self->{api_secret} && length $self->{api_secret}){
        if(defined $self->{auth_token} && length $self->{auth_token}){
            $args->{auth_token} = $self->{auth_token};
        }
        $args->{api_sig} = $self->sign_args($args);
    }
    $args->{photo} = [$photo] if ref $photo ne "ARRAY";
    return $self->post("", Content_Type => "form-data", Content => $args);
}

sub request_auth_url {
    my ($self, $perms, $frob) = @_;
    
    return undef unless defined $self->{api_secret} && length $self->{api_secret};
    
    my %args = (
        'api_key' => $self->basic_params->{api_key},
        'perms'   => $perms
        );
    
    if ($frob) {
        $args{frob} = $frob;
    }
    
    my $sig = $self->sign_args(\%args);
    $args{api_sig} = $sig;
    
    my $uri = URI->new('http://flickr.com/services/auth');
    $uri->query_form(%args);
    
    return $uri;
}

1;
