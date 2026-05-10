/**
 * MySQL/MariaDB: normalize text expressions before comparing them.
 * This keeps legacy `utf8mb4_general_ci` columns compatible with newer
 * `utf8mb4_unicode_ci` tables, and also protects column-vs-parameter checks.
 */
function collateExpr(expr) {
  return `CONVERT(${expr} USING utf8mb4) COLLATE utf8mb4_unicode_ci`;
}

function collateParam() {
  return `CAST(? AS CHAR CHARACTER SET utf8mb4) COLLATE utf8mb4_unicode_ci`;
}

function collateEq(leftExpr, rightExpr) {
  return `${collateExpr(leftExpr)} = ${collateExpr(rightExpr)}`;
}

module.exports = { collateEq, collateExpr, collateParam };
