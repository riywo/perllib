package WebService::Simple::Flickr;

use base qw(WebService::Simple);
__PACKAGE__->config(
    base_url   => "http://api.flickr.com/services/rest/",
);

sub test_echo {
    my ($self,$str) = @_;
    return $self->get( { method => "flickr.test.echo", name => $str } );
}

sub photos_search {
    my ($self,$str) = @_;
    return $self->get( { method => "flickr.photos.search", text => $str } );
}
