using Microsoft.Data.SqlClient;

namespace Diti365.Infrastructure.Repositories;

/// <summary>
/// Reader mappers.
///
/// Every member is a FACTORY: it takes the reader once, resolves all ordinals, and
/// returns a delegate that maps a row. The ordinals are therefore resolved once per
/// result set rather than once per column per row. Reading by name inside the loop is
/// the classic ADO.NET performance mistake and is banned here.
///
/// Each mapper only touches columns its procedure actually selects. OrdinalOrDefault
/// is used where a column is optional across the procedures sharing a shape.
/// </summary>
public static partial class Map
{
}
