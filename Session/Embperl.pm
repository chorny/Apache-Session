#############################################################################
#
# Apache::Session::Embperl
# A bridge between Apache::Session and Embperl's %udat hash
# Copyright(c) 1999 Gerald Richter (richter@ecos.de)
# Copyright(c) 1998, 1999 Jeffrey William Baker (jeffrey@kathyandjeffrey.net)
# Distribute under the Artistic License
#
#############################################################################

=head1 NAME

Apache::Session::Embperl - works with HTML::Embperl

=head1 DESCRIPTION

An adaptation of Apache::Session to work with HTML::Embperl

=head1 SYNOPSIS

=head2 Addtional Attributes for TIE

=over 4

=item lazy

By Specifing this attribute, you tell Apache::Session to not do any
access to the object store, until the first read or write access to
the tied hash. Otherwise the B<tie> function will make sure the hash
exist or creates a new one.

=item create_unknown

Setting this to one causes Apache::Session to create a new session
when the specified session id does not exists. Otherwise it will die.

=item object_store

Specify the class for the object store. (The Apache::Session:: prefix is
optional)

=item lock_manager

Specify the class for the lock manager. (The Apache::Session:: prefix is
optional)

=back

Example using attrubtes to specfiy store and object classes instead of
a derived class:

 use Apache::Session ;

 tie %session, 'Apache::Session', undef,
    { 
    object_store => 'DBIStore',
    lock_manager => 'SysVSemaphoreLocker',
    DataSource => 'dbi:Oracle:db' 
    };

NOTE: Apache::Session will require the nessecary additional perl modules for you.


=head2 Addtional Methods

=over 4

=item setid

Set the session id for futher accesses.

=item getid

Get the session id. The difference to using $session{_session_id} is,
that in lazy mode, getid will B<not> create a new session id, if it
doesn't exists.

=item cleanup

Writes any pending data, releases all locks and deletes all data from memory.

=back

=head1 AUTHORS

This class was written by Jeffrey Baker (jeffrey@kathyandjeffrey.net)
but it is taken wholesale from a patch that Gerald Richter
(richter@ecos.de) sent me against Apache::Session

=cut 

package Apache::Session::Embperl;

use strict;
use vars qw(@ISA $VERSION);

$VERSION = '0.90';
@ISA = qw(Apache::Session);

use Apache::Session;

sub TIEHASH {
    my $class = shift;
    
    my $session_id = shift;
    my $args       = shift || {};

    if(ref $args ne "HASH") {
        die "Additional arguments should be in the form of a hash reference";
    }

    # check object_store and lock_manager classes
    
    if ($args -> {'object_store'})
        {
        $args -> {'object_store'} = "Apache::Session::$args->{'object_store'}" if (!($args -> {'object_store'} =~ /::/)) ;
        eval "require $args->{'object_store'}" ;
        die "Cannot require $args->{'object_store'}" if ($@) ;
        }

    if ($args -> {'lock_manager'})
        {
        $args -> {'lock_manager'} = "Apache::Session::$args->{'lock_manager'}" if (!($args -> {'lock_manager'} =~ /::/)) ;
        eval "require $args->{'lock_manager'}" ;
        die "Cannot require $args->{'lock_manager'}" if ($@) ;
        }
        
    #Set-up the data structure and make it an object
    #of our class

    my $self = {
        args         => $args,
        data         => { _session_id => $session_id },
        lock         => 0,
        lock_manager => undef,
        object_store => undef,
        status       => 0
    };
    
    bless $self, $class;

    $self -> init if (!$args -> {'lazy'}) ;


    return $self ;
    }


sub init
    {
    my $self = shift ;

    #If a session ID was passed in, this is an old hash.
    #If not, it is a fresh one.

    my $session_id = $self->{data}->{_session_id} ;

    if (defined $session_id) {
        $self->{status} &= ($self->{status} ^ NEW());

	if ($self -> {'args'}{'create_unknown'})
	    {
            eval { $self -> restore } ;
	    $session_id = $self->{data}->{_session_id} ;
	    }
	else
	    {
	    $self->restore;
	    }
    }

    if (!($self->{status} & SYNCED()))
        {
        $self->{status} |= NEW();
	$self->{data}->{_session_id} = generate_id() if (!$self->{data}->{_session_id}) ;
        $self->save;
    }
    
    return $self;
}

sub FETCH {
    my $self = shift;
    my $key  = shift;

    $self -> init if (!$self -> {'status'}) ;

    return $self->{data}->{$key};
}

sub STORE {
    my $self  = shift;
    my $key   = shift;
    my $value = shift;
    
    $self -> init if (!$self -> {'status'}) ;

    $self->{data}->{$key} = $value;
    
    $self->{status} |= MODIFIED();
    
    return $self->{data}->{$key};
}

sub DELETE {
    my $self = shift;
    my $key  = shift;
    
    $self -> init if (!$self -> {'status'}) ;

    $self->{status} |= MODIFIED();
    
    delete $self->{data}->{$key};
}

sub CLEAR {
    my $self = shift;

    $self -> init if (!$self -> {'status'}) ;

    $self->{status} |= MODIFIED();
    
    $self->{data} = {};
}

sub EXISTS {
    my $self = shift;
    my $key  = shift;
    
    $self -> init if (!$self -> {'status'}) ;

    return exists $self->{data}->{$key};
}

sub FIRSTKEY {
    my $self = shift;
    
    $self -> init if (!$self -> {'status'}) ;

    my $reset = keys %{$self->{data}};
    return each %{$self->{data}};
}

sub NEXTKEY {
    my $self = shift;
    
    $self -> init if (!$self -> {'status'}) ;

    return each %{$self->{data}};
}

sub DESTROY {
    my $self = shift;
    
    return if (!$self -> {'status'}) ;

    $self->save;
    $self->release_all_locks;
}

sub cleanup {
    my $self = shift;
    
    if (!$self -> {'status'})
	{
	$self->{data} = {} ;
	return ;
	}

    $self->save;
    $self->release_all_locks;

    $self->{'status'} = 0 ;
    $self->{data} = {} ;
}


sub setid {
    my $self = shift;

    $self->{'status'} = 0 ;
    $self->{data}->{_session_id} = shift ;
}

sub getid {
    my $self = shift;

    return $self->{data}->{_session_id} ;
}


sub get_object_store {
    my $self = shift;

    return new {$self -> {'args'}{'object_store'}} $self;
}

sub get_lock_manager {
    my $self = shift;
    
    return new {$self -> {'args'}{'lock_manager'}} $self;
}

1
