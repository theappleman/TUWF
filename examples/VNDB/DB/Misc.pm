
package VNDB::DB::Misc;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = ('dbVNInfo');


# small example showing how execute an SQL query and return the results
sub dbVNInfo {
  my($s, $id) = @_;
  return $s->dbRow(q|
    SELECT vr.id, vr.title, vr.original
    FROM vn v
    JOIN vn_rev vr ON vr.id = v.latest
    WHERE v.id = ?
    LIMIT 1|,
    $id);
}


1;
