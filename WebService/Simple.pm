# $Id$

package WebService::Simple;
use strict;
use warnings;
use base qw(LWP::UserAgent Class::Data::ConfigHash);
use Class::Inspector;
use Data::Dumper ();
use Digest::MD5  ();
use URI::Escape;
use WebService::Simple::Response;
use UNIVERSAL::require;

our $VERSION = '0.13';

__PACKAGE__->config(
    base_url        => '',
    response_parser => { module => "XML::Simple" },
);

sub new {
    my $class    = shift;
    my %args     = @_;
    my $base_url = delete $args{base_url}
      || $class->config->{base_url}
      || Carp::croak("base_url is required");
    my $basic_params = delete $args{params} || delete $args{param} || {};
    my $debug = delete $args{debug} || 0;

    my $response_parser = delete $args{response_parser}
      || $class->config->{response_parser};
    if (   !$response_parser
        || !eval { $response_parser->isa('WebService::Simple::Parser') } )
    {
        my $config = $response_parser || $class->config->{response_parser};
        if ( !ref $config ) {
            $config = { module => $config };
        }
        my $module = $config->{module};
        if ( $module !~ s/^\+// ) {
            $module = __PACKAGE__ . "::Parser::$module";
        }
        if ( !Class::Inspector->loaded($module) ) {
            $module->require or die;
        }
        $response_parser = $module->new( %{ $config->{args} || {} } );
    }

    my $cache = delete $args{cache};
    if ( !$cache || ref $cache eq 'HASH' ) {
        my $config = ref $cache eq 'HASH' ? $cache : $class->config->{cache};
        if ($config) {
            if ( !ref $config ) {
                $config = { module => $config };
            }

            my $module = $config->{module};
            if ( !Class::Inspector->loaded($module) ) {
                $module->require or die;
            }
            $cache =
              $module->new( $config->{hashref_args}
                ? $config->{args}
                : %{ $config->{args} } );
        }
    }

    my $self = $class->SUPER::new(%args);
    $self->{base_url}        = URI->new($base_url);
    $self->{basic_params}    = $basic_params;
    $self->{response_parser} = $response_parser;
    $self->{cache}           = $cache;
    $self->{debug}           = $debug;
    return $self;
}

sub base_url        { $_[0]->{base_url} }
sub basic_params    { $_[0]->{basic_params} }
sub response_parser { $_[0]->{response_parser} }
sub cache           { $_[0]->{cache} }

sub __cache_get {
    my $self  = shift;
    my $cache = $self->cache;
    return unless $cache;

    my $key = $self->__cache_key(shift);
    return $cache->get( $key, @_ );
}

sub __cache_set {
    my $self  = shift;
    my $cache = $self->cache;
    return unless $cache;

    my $key = $self->__cache_key(shift);
    return $cache->set( $key, @_ );
}

sub __cache_remove {
    my $self  = shift;
    my $cache = $self->cache;
    return unless $cache;

    my $key = $self->__cache_key(shift);
    return $cache->remove( $key, @_ );
}

sub __cache_key {
    my $self = shift;
    local $Data::Dumper::Indent   = 1;
    local $Data::Dumper::Terse    = 1;
    local $Data::Dumper::Sortkeys = 1;
    return Digest::MD5::md5_hex( Data::Dumper::Dumper( $_[0] ) );
}

sub request_url {
    my $self = shift;
    my %args = @_;

    my $uri = URI->new( $args{url} );
    if ( my $extra_path = $args{extra_path} ) {
        $extra_path =~ s!^/!!;
        $uri->path( $uri->path . $extra_path );
    }

    $uri->query_form(%{$args{params}});
    return $uri;
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

    my $uri = $self->request_url(
        url        => $self->base_url,
        extra_path => $url,
        params     => { %{ $self->basic_params }, %extra }
    );

    warn "Request URL is $uri\n" if $self->{debug};

    my @headers = @_;

    my $response;
    $response = $self->__cache_get( [ $uri, @headers ] );
    if ($response) {
        return $response;
    }

    $response = $self->SUPER::get( $uri, @headers );
    if ( !$response->is_success ) {
        Carp::croak("request to $uri failed");
    }

    $response = WebService::Simple::Response->new_from_response(
        response => $response,
        parser   => $self->response_parser
    );
    $self->__cache_set( [ $uri, @headers ], $response );
    return $response;
}

sub post {
    my ( $self, $url, @params ) = @_;

    # XXX - do not include params
    my $uri = $self->request_url(
        url        => $self->base_url,
        extra_path => $url
    );

    # default parameters must come *before* @params, so unshift instead
    # of push
    unshift @params, %{ $self->basic_params };
    my $response = $self->SUPER::post( $uri, @params );

    if ( !$response->is_success ) {
        Carp::croak( "request to $url failed: " . $response->status_line );
    }
    $response = WebService::Simple::Response->new_from_response(
        response => $response,
        parser   => $self->response_parser
    );
    return $response;
}

1;

__END__

=head1 NAME

WebService::Simple - Simple Interface To Web Services APIs

=head1 SYNOPSIS

  use WebService::Simple;

  # Simple use case
  my $flickr = WebService::Simple->new(
    base_url => "http://api.flickr.com/services/rest/",
    param    => { api_key => "your_api_key", }
  );

  # send GET request to 
  # http://api.flickr.com/service/rest/?api_key=your_api_key&method=flickr.test.echo&name=value
  $flickr->get( { method => "flickr.test.echo", name => "value" } );

  # send GET request to 
  # http://api.flickr.com/service/rest/extra/path?api_key=your_api_key&method=flickr.test.echo&name=value
  $flickr->get( "extra/path",
    { method => "flickr.test.echo", name => "value" });

=head1 DESCRIPTION

WebService::Simple is a simple class to interact with web services.

It's basically an LWP::UserAgent that remembers recurring api URLs and
parameters, plus sugar to parse the results.

=head1 METHODS

=over 4

=item new(I<%args>)

    my $flickr = WebService::Simple->new(
        base_url => "http://api.flickr.com/services/rest/",
        param    => { api_key => "your_api_key", },
        # debug    => 1
    );

Create and return a new WebService::Simple object.
"new" Method requires a base_url of Web Service API.
If debug is set, dump a request URL in get or post method.

=item get(I<[$extra_path,] $args>)

    my $response =
      $flickr->get( { method => "flickr.test.echo", name => "value" } );

Send GET request, and you can get  the WebService::Simple::Response object.
If you want to add a path to base URL, use an option parameter.

    my $lingr = WebService::Simple->new(
        base_url => "http://www.lingr.com/",
        param    => { api_key => "your_api_key", format => "xml" }
    );
    my $response = $lingr->get( 'api/session/create', {} );

=item post(I<[$extra_path,] $args>)

Send POST request.

=item request_url(I<$extra_path, $args>)

Return reequest URL.

=item base_url

=item basic_params

=item cache

=item response_parser

=back

=head1 SUBCLASSING

For better encapsulation, you can create subclass of WebService::Simple to
customize the behavior

  package WebService::Simple::Flickr;
  use base qw(WebService::Simple);
  __PACKAGE__->config(
    base_url => "http://api.flickr.com/services/rest/",
    upload_url => "http://api.flickr.com/services/upload/",
  );

  sub test_echo
  {
    my $self = shift;
    $self->get( { method => "flickr.test.echo", name => "value" } );
  }

  sub upload
  {
    my $self = shift;
    local $self->{base_url} = $self->config->{upload_url};
    $self->post( 
      Content_Type => "form-data",
      Content => { title => "title", description => "...", photo => ... },
    );
  }


=head1 PARSERS

Web services return their results in various different formats. Or perhaps
you require more sophisticated results parsing than what WebService::Simple
provides.

WebService::Simple by default uses XML::Simple, but you can easily override
that by providing a parser object to the constructor:

  my $service = WebService::Simple->new(
    response_parser => AVeryComplexParser->new,
    ...
  );
  my $response = $service->get( ... );
  my $thing = $response->parse_response;

This allows great flexibility in handling different webservices

=head1 CACHING

You can cache the response of Web Service by using Cache object.

  my $cache   = Cache::File->new(
      cache_root      => '/tmp/mycache',
      default_expires => '30 min',
  );
  
  my $flickr = WebService::Simple->new(
      base_url => "http://api.flickr.com/services/rest/",
      cache    => $cache,
      param    => { api_key => "your_api_key, }
  );


=head1 AUTHOR

Yusuke Wada  C<< <yusuke@kamawada.com> >>

Daisuke Maki C<< <daisuke@endeworks.jp> >>

Matsuno Tokuhiro

=head1 COPYRIGHT AND LICENSE

This module is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.
See L<perlartistic>.

=cut
