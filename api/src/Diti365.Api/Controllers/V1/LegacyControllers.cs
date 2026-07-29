// Superseded.
//
// Two legacy-compatibility implementations were written in parallel. The set kept is
// LegacyControllerBase.cs + UsersController.cs + OperationController.cs +
// TasksController.cs + SalesController.cs + ReportController.cs.
//
// It covers 127 endpoints against the 90 here, contains every endpoint this file had,
// and factors the envelope helpers into a base class instead of repeating them.
//
// This file is emptied rather than deleted because the sandbox cannot remove files on
// the host. Delete it when convenient. See DECISIONS.md #28.

