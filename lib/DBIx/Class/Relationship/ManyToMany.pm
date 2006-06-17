package # hide from PAUSE
    DBIx::Class::Relationship::ManyToMany;

use strict;
use warnings;

sub many_to_many {
  my ($class, $meth, $rel, $f_rel, $rel_attrs) = @_;
  {
    no strict 'refs';
    no warnings 'redefine';

    my $remove_link_meth = "remove_from_$rel";
    my $add_link_meth = "add_to_$rel";

    *{"${class}::${meth}"} = sub {
      my $self = shift;
      my $attrs = @_ > 1 && ref $_[$#_] eq 'HASH' ? pop(@_) : {};
      $self->search_related($rel)->search_related(
        $f_rel, @_ > 0 ? @_ : undef, { %{$rel_attrs||{}}, %$attrs }
      );
    };

    *{"${class}::add_to_${meth}"} = sub {
      my $self = shift;
      @_ > 0 or $self->throw_exception(
        "$add_link_meth needs an object or hashref"
      );
      my $source = $self->result_source;
      my $schema = $source->schema;
      my $rel_source_name = $source->relationship_info($rel)->{source};
      my $rel_source = $schema->resultset($rel_source_name)->result_source;
      my $f_rel_source_name = $rel_source->relationship_info($f_rel)->{source};
      my $f_rel_rs = $schema->resultset($f_rel_source_name);
      my $obj = ref $_[0]
        ? ( ref $_[0] eq 'HASH' ? $f_rel_rs->create($_[0]) : $_[0] )
        : ( $f_rel_rs->create({@_}) );
      my $link = $self->search_related($rel)->new_result({});
      $link->set_from_related($f_rel, $obj);
      $link->insert();
    };

    *{"${class}::remove_from_${meth}"} = sub {
      my $self = shift;
      @_ > 0 && ref $_[0] ne 'HASH'
        or $self->throw_exception("$remove_link_meth needs an object");
      my $obj = shift;
      my $rel_source = $self->search_related($rel)->result_source;
      my $cond = $rel_source->relationship_info($f_rel)->{cond};
      my $link_cond = $rel_source->resolve_condition(
        $cond, $obj, $f_rel
      );
      $self->search_related($rel, $link_cond)->delete;
    };

  }
}

1;
