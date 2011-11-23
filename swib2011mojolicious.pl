#!/usr/bin/perl

use v5.10;

use utf8;
use strict;
use autodie;
use warnings;
use charnames qw< :full >;
use feature qw< unicode_strings >;
use Carp qw< carp croak confess cluck >;
use Encode;

# Cache
use Cache::FileCache;
my $cache = new Cache::FileCache( { 'cache_root' => 'cache/' } );

# Mojolicious Web Framework
use Mojolicious::Lite;
use Mojolicious::Types;
use Mojo::UserAgent;
use Mojo::DOM;

use Pod::Simple::XHTML;

# RDF Modules
use RDF::Trine;
use RDF::Lazy;
use RDF::NS;
use RDF::Dumper;

# Hilfsfunktion für 303 redirect von der Non Information Resource zu Information Resource
helper redirect_to_with_303 => sub {
    my $self = shift;
    $self->res->code(303);
    $self->res->headers->location( $self->url_for(@_)->to_abs );
    $self->res->headers->content_type('text/plain');
    $self->res->headers->content_length(0);
    $self->rendered;
    return $self;
};

# Generiert anhand der POD-Dokumentation eine Index-Seite
get '/' => sub {
    my $self = shift;
    my $psx  = Pod::Simple::XHTML->new;
    $psx->output_string( \my $xhtml );
    $psx->html_doctype(
        '<?xml version="1.0" ?>
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">'
    );
    $psx->html_charset('UTF-8');
    $psx->force_title('SWIB2011mojolicious');
    $psx->parse_file('doc/swib2011mojolicious.pod');
    $self->render( text => $xhtml );
};

# HTTP-URI der Non Information Resource
# führt einen 303 redirect zur Information Resource aus oder liefert 404
get '/isil/resource/:id' => sub {
    my $self = shift;
    my $id   = $self->param('id');
    if ( my $data = $cache->get($id) ) {
        $self->redirect_to_with_303("http://127.0.0.1:3000/isil/data/$id");
    }
    elsif ( my $record = get_record($id) ) {
        $cache->set( $id, $record );
        $self->redirect_to_with_303("http://127.0.0.1:3000/isil/data/$id");
    }
    else {
        $self->render_text( "404", status => 404 );

    }
};

# HTTP-URI der Information Resource
get '/isil/data/:id' => sub {
    my $self = shift;
    app->types->type( rdf => 'application/rdf' );
    $self->respond_to(
        rdf => sub {
            my $id = $self->param('id');
            if ( my $data = $cache->get($id) ) {
                $self->res->headers->content_type('application/rdf+xml');
                $self->render( text => "$data" );
            }
            else {
                $self->render_text( "404", status => 404 );
            }
        },
        html => sub {
            my $id = $self->param('id');
            if ( my $ir = $cache->get($id) ) {
                $self->redirect_to(
                    qq[http://lobid.org/organisation/$id/about.html] );
            }
            else {
                $self->render_text( "404", status => 404 );
            }
        },
    );
};

# Beispiel einer Subroutine um Daten von externen einer externen Quelle zu holen
sub get_record {
    my $id = shift;
    my $ua = Mojo::UserAgent->new;
    my $data =
      $ua->get(qq[http://lobid.org/organisation/data/$id.rdf])->res->body;
    if ($data) {
        return $data;
    }
    else {
        return;
    }
}

app->start;
