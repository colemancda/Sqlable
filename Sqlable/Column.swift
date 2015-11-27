//
//  Column.swift
//  Simplyture
//
//  Created by Ulrik Damm on 27/10/2015.
//  Copyright © 2015 Robocat. All rights reserved.
//

import Foundation

protocol ColumnOption : SqlPrintable {
	
}

struct PrimaryKey : ColumnOption {
	let autoincrement : Bool
	
	var sqlDescription : String {
		return "primary key" + (autoincrement ? " autoincrement" : "")
	}
}

enum Rule : SqlPrintable {
	case Ignore, Cascade, SetNull, SetDefault
	
	var sqlDescription : String {
		switch self {
		case .Ignore: return "no action"
		case .Cascade: return "cascade"
		case .SetNull: return "set null"
		case .SetDefault: return "set default"
		}
	}
}

struct ForeignKey<To : Sqlable> : ColumnOption, SqlPrintable {
	let column : String
	let onDelete : Rule
	let onUpdate : Rule
	
	init(column : String = "id", onDelete : Rule = .Ignore, onUpdate : Rule = .Ignore) {
		self.column = column
		self.onDelete = onDelete
		self.onUpdate = onUpdate
	}
	
	var sqlDescription : String {
		return "references \(To.tableName)(\(column)) on update \(onUpdate.sqlDescription) on delete \(onDelete.sqlDescription)"
	}
}

struct Column : Equatable {
	let name : String
	let type : SqlType
	let options : [ColumnOption]
	
	init(_ name : String, _ type : SqlType, _ options : ColumnOption...) {
		self.name = name
		self.type = type
		self.options = options
	}
}

func ==(lhs : Column, rhs : Column) -> Bool {
	return lhs.name == rhs.name && lhs.type == rhs.type
}

func ~=(lhs : Column, rhs : Column) -> Bool {
	return lhs.name == rhs.name
}

extension Column : SqlPrintable {
	var sqlDescription : String {
		var statement = "\(name) \(type.sqlDescription)"
		
		if options.count > 0 {
			let optionsString = options.map { $0.sqlDescription }.joinWithSeparator(" ")
			statement += " \(optionsString)"
		}
		
		return statement
	}
}

indirect enum Expression : SqlPrintable {
	case And(Expression, Expression)
	case Or(Expression, Expression)
	case EqualsValue(Column, SqlValue)
	case Inverse(Expression)
	case LessThan(Column, SqlValue)
	case LessThanOrEqual(Column, SqlValue)
	case GreaterThan(Column, SqlValue)
	case GreaterThanOrEqual(Column, SqlValue)
	
	var sqlDescription : String {
		switch self {
		case .And(let lhs, let rhs): return "(\(lhs.sqlDescription)) and (\(rhs.sqlDescription))"
		case .Or(let lhs, let rhs): return "(\(lhs.sqlDescription)) or (\(rhs.sqlDescription))"
		case .Inverse(let expr): return "not (\(expr.sqlDescription))"
		case LessThan(let lhs, _): return "(\(lhs.name)) < ?"
		case LessThanOrEqual(let lhs, _): return "(\(lhs.name)) <= ?"
		case GreaterThan(let lhs, _): return "(\(lhs.name)) > ?"
		case GreaterThanOrEqual(let lhs, _): return "(\(lhs.name)) >= ?"
		case .EqualsValue(let column, is Null): return "\(column.name) is null"
		case .EqualsValue(let column, _): return "\(column.name) == ?"
		}
	}
	
	var values : [SqlValue] {
		switch self {
		case .And(let lhs, let rhs): return lhs.values + rhs.values
		case .Or(let lhs, let rhs): return lhs.values + rhs.values
		case .Inverse(let expr): return expr.values
		case .EqualsValue(_, is Null): return []
		case .EqualsValue(_, let value): return [value]
		case LessThan(_, let rhs): return [rhs]
		case LessThanOrEqual(_, let rhs): return [rhs]
		case GreaterThan(_, let rhs): return [rhs]
		case GreaterThanOrEqual(_, let rhs): return [rhs]
		}
	}
}

func ==(lhs : Column, rhs : SqlValue) -> Expression {
	return .EqualsValue(lhs, rhs)
}

func !=(lhs : Column, rhs : SqlValue) -> Expression {
	return .Inverse(.EqualsValue(lhs, rhs))
}

func <(lhs : Column, rhs : SqlValue) -> Expression {
	return .LessThan(lhs, rhs)
}

func <=(lhs : Column, rhs : SqlValue) -> Expression {
	return .LessThanOrEqual(lhs, rhs)
}

func >(lhs : Column, rhs : SqlValue) -> Expression {
	return .GreaterThan(lhs, rhs)
}

func >=(lhs : Column, rhs : SqlValue) -> Expression {
	return .GreaterThanOrEqual(lhs, rhs)
}

func &&(lhs : Expression, rhs : Expression) -> Expression {
	return .And(lhs, rhs)
}

func ||(lhs : Expression, rhs : Expression) -> Expression {
	return .Or(lhs, rhs)
}

prefix func !(value : Expression) -> Expression {
	return .Inverse(value)
}

prefix func !(column : Column) -> Expression {
	return column == Null()
}
