#!/usr/bin/env python3
"""
Cursor Chat History Export Tool

This script searches through Cursor's workspace storage SQLite databases
to extract chat history based on time periods and keywords.

Usage:
    python export_chats.py --keywords "rails,api,authentication" --start-date "2024-01-01" --output-dir ./exports
"""

import sqlite3
import json
import argparse
import os
import glob
from datetime import datetime
from pathlib import Path
import re
from typing import List, Dict, Optional, Any

class CursorChatExporter:
    def __init__(self, storage_path: Optional[str] = None):
        """Initialize the exporter with the Cursor storage path."""
        if storage_path is None:
            # Default Mac path
            storage_path = os.path.expanduser("~/Library/Application Support/Cursor/User/workspaceStorage")
        
        self.storage_path = Path(storage_path)
        self.found_databases = []
        self.chat_data = []
    
    def find_databases(self, recent_hours: int = None) -> List[Path]:
        """Find all state.vscdb files in the workspace storage."""
        print(f"Searching for databases in: {self.storage_path}")
        
        if not self.storage_path.exists():
            print(f"Warning: Storage path does not exist: {self.storage_path}")
            return []
        
        # Search for state.vscdb files recursively
        db_pattern = str(self.storage_path / "**/state.vscdb")
        databases = [Path(p) for p in glob.glob(db_pattern, recursive=True)]
        
        # Filter by recent modification time if specified
        if recent_hours:
            cutoff_time = datetime.now().timestamp() - (recent_hours * 3600)
            recent_databases = []
            for db in databases:
                if db.stat().st_mtime > cutoff_time:
                    recent_databases.append(db)
            databases = recent_databases
            print(f"Found {len(databases)} database files modified in the last {recent_hours} hours")
        else:
            print(f"Found {len(databases)} database files")
        
        self.found_databases = databases
        return databases
    
    def extract_workspace_info(self, db_path: Path) -> Dict[str, Any]:
        """Extract workspace information from the database path."""
        # Workspace folders typically have encoded names
        parent_dir = db_path.parent.name
        return {
            "workspace_id": parent_dir,
            "db_path": str(db_path),
            "last_modified": datetime.fromtimestamp(db_path.stat().st_mtime).isoformat()
        }
    
    def query_database(self, db_path: Path) -> List[Dict[str, Any]]:
        """Query a single database for chat-related data."""
        chats = []
        
        try:
            conn = sqlite3.connect(str(db_path))
            conn.row_factory = sqlite3.Row  # This enables column access by name
            cursor = conn.cursor()
            
            # Get all table names to understand the schema
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
            tables = [row[0] for row in cursor.fetchall()]
            
            print(f"Tables in {db_path.name}: {tables}")
            
            # Check ALL tables, not just chat-related patterns
            # Cursor might store data in unexpected table names
            for table in tables:
                try:
                    # Get table schema first
                    cursor.execute(f"PRAGMA table_info({table});")
                    columns = [col[1] for col in cursor.fetchall()]
                    
                    # Count rows to avoid processing empty tables
                    cursor.execute(f"SELECT COUNT(*) FROM {table};")
                    row_count = cursor.fetchone()[0]
                    
                    if row_count > 0:
                        print(f"  {table}: {row_count} rows, columns: {columns}")
                        
                        # Get a sample of rows to analyze
                        cursor.execute(f"SELECT * FROM {table} LIMIT 10;")
                        sample_rows = cursor.fetchall()
                        
                        for row in sample_rows:
                            row_dict = dict(row)
                            
                            # Look for chat-specific keys first
                            chat_content = self.extract_chat_content(row_dict)
                            if chat_content:
                                chat_entry = {
                                    "workspace": self.extract_workspace_info(db_path),
                                    "table": table,
                                    "columns": columns,
                                    "raw_data": row_dict,
                                    "text_content": chat_content,
                                    "timestamp": self.extract_timestamp(row_dict),
                                    "data_type": "chat_data"
                                }
                                chats.append(chat_entry)
                            
                            # Also look for ANY text content that might be meaningful
                            text_content = self.extract_text_content_broad(row_dict)
                            if text_content:
                                chat_entry = {
                                    "workspace": self.extract_workspace_info(db_path),
                                    "table": table,
                                    "columns": columns,
                                    "raw_data": row_dict,
                                    "text_content": text_content,
                                    "timestamp": self.extract_timestamp(row_dict)
                                }
                                chats.append(chat_entry)
                    else:
                        print(f"  {table}: empty")
                                
                except sqlite3.Error as e:
                    print(f"Error querying table {table}: {e}")
                    continue
            
            conn.close()
            
        except sqlite3.Error as e:
            print(f"Error accessing database {db_path}: {e}")
        
        return chats
    
    def extract_text_content(self, row_dict: Dict[str, Any]) -> Optional[str]:
        """Extract text content from a database row."""
        text_content = []
        
        for key, value in row_dict.items():
            if value is None:
                continue
                
            # Convert to string and check if it looks like meaningful text
            str_value = str(value)
            
            # Skip very short strings, numbers, and obvious metadata
            if len(str_value) < 10:
                continue
                
            # Look for JSON-like content, markdown, or long text
            if (str_value.startswith('{') or 
                str_value.startswith('[') or 
                '```' in str_value or
                len(str_value) > 50):
                
                text_content.append(f"{key}: {str_value}")
        
        return "\n".join(text_content) if text_content else None
    
    def extract_text_content_broad(self, row_dict: Dict[str, Any]) -> Optional[str]:
        """Extract ANY text content from a database row with broader criteria."""
        text_content = []
        
        for key, value in row_dict.items():
            if value is None:
                continue
                
            # Convert to string
            str_value = str(value)
            
            # Look for any meaningful text content
            if (len(str_value) > 5 and  # Longer than just IDs
                not str_value.isdigit() and  # Not just numbers
                not (len(str_value) < 50 and str_value.replace('-', '').replace('_', '').isalnum())):  # Not just IDs
                
                text_content.append(f"{key}: {str_value}")
        
        return "\n".join(text_content) if text_content else None
    
    def extract_chat_content(self, row_dict: Dict[str, Any]) -> Optional[str]:
        """Extract chat-specific content from Cursor database rows."""
        if 'key' not in row_dict or 'value' not in row_dict:
            return None
            
        key = str(row_dict['key'])
        value = str(row_dict['value'])
        
        # Look for specific chat-related keys
        chat_keys = [
            'composer.composerData',
            'workbench.panel.aichat',
            'workbench.panel.composerChatViewPane',
            'aiService.generations',
            'aiService.prompts'
        ]
        
        if any(chat_key in key for chat_key in chat_keys):
            return f"CHAT_DATA - {key}: {value}"
            
        return None
    
    def extract_timestamp(self, row_dict: Dict[str, Any]) -> Optional[str]:
        """Extract timestamp from a database row."""
        timestamp_keys = ['timestamp', 'created_at', 'updated_at', 'time', 'date']
        
        for key in timestamp_keys:
            if key in row_dict and row_dict[key]:
                try:
                    # Try to parse as Unix timestamp
                    if isinstance(row_dict[key], (int, float)):
                        # Handle both seconds and milliseconds
                        ts = row_dict[key]
                        if ts > 1e12:  # Milliseconds
                            ts = ts / 1000
                        return datetime.fromtimestamp(ts).isoformat()
                    
                    # Try to parse as string
                    return str(row_dict[key])
                except (ValueError, OSError):
                    continue
        
        return None
    
    def filter_by_keywords(self, chats: List[Dict[str, Any]], keywords: List[str]) -> List[Dict[str, Any]]:
        """Filter chats by keywords."""
        if not keywords:
            return chats
        
        filtered = []
        keywords_lower = [k.lower() for k in keywords]
        
        for chat in chats:
            text = chat.get('text_content', '').lower()
            if any(keyword in text for keyword in keywords_lower):
                chat['matched_keywords'] = [k for k in keywords_lower if k in text]
                filtered.append(chat)
        
        return filtered
    
    def filter_by_date(self, chats: List[Dict[str, Any]], start_date: Optional[str], end_date: Optional[str]) -> List[Dict[str, Any]]:
        """Filter chats by date range."""
        if not start_date and not end_date:
            return chats
        
        filtered = []
        
        try:
            start_dt = datetime.fromisoformat(start_date) if start_date else None
            end_dt = datetime.fromisoformat(end_date) if end_date else None
        except ValueError as e:
            print(f"Invalid date format: {e}")
            return chats
        
        for chat in chats:
            timestamp_str = chat.get('timestamp')
            if not timestamp_str:
                continue
                
            try:
                chat_dt = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                
                if start_dt and chat_dt < start_dt:
                    continue
                if end_dt and chat_dt > end_dt:
                    continue
                    
                filtered.append(chat)
            except ValueError:
                continue
        
        return filtered
    
    def export_chats(self, output_dir: str, keywords: List[str] = None, 
                    start_date: str = None, end_date: str = None, debug_mode: bool = False, 
                    recent_hours: int = None) -> str:
        """Main export function."""
        print("Starting chat export...")
        
        # Find all databases
        databases = self.find_databases(recent_hours)
        if not databases:
            print("No databases found!")
            return ""
        
        # In debug mode, only process the most recent databases
        if debug_mode:
            # Sort by modification time, most recent first
            databases.sort(key=lambda x: x.stat().st_mtime, reverse=True)
            databases = databases[:5]  # Only process 5 most recent
            print(f"Debug mode: processing only {len(databases)} most recent databases")
        
        # Extract data from all databases
        all_chats = []
        for db_path in databases:
            print(f"\nProcessing: {db_path}")
            chats = self.query_database(db_path)
            all_chats.extend(chats)
            print(f"Found {len(chats)} potential chat entries")
        
        print(f"\nTotal entries found: {len(all_chats)}")
        
        # Apply filters
        if keywords:
            print(f"Filtering by keywords: {keywords}")
            all_chats = self.filter_by_keywords(all_chats, keywords)
            print(f"After keyword filter: {len(all_chats)} entries")
        
        if start_date or end_date:
            print(f"Filtering by date range: {start_date} to {end_date}")
            all_chats = self.filter_by_date(all_chats, start_date, end_date)
            print(f"After date filter: {len(all_chats)} entries")
        
        # Create output directory
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        # Generate output filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        keywords_str = "_".join(keywords) if keywords else "all"
        filename = f"cursor_chats_{keywords_str}_{timestamp}.json"
        output_file = output_path / filename
        
        # Save results
        export_data = {
            "export_info": {
                "timestamp": timestamp,
                "total_entries": len(all_chats),
                "keywords": keywords,
                "date_range": {"start": start_date, "end": end_date},
                "databases_processed": len(databases)
            },
            "chats": all_chats
        }
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(export_data, f, indent=2, ensure_ascii=False, default=str)
        
        print(f"\nExport completed: {output_file}")
        print(f"Total entries exported: {len(all_chats)}")
        
        return str(output_file)

def main():
    parser = argparse.ArgumentParser(description="Export chat history from Cursor workspace storage")
    parser.add_argument("--storage-path", help="Path to Cursor workspace storage (default: Mac default)")
    parser.add_argument("--keywords", help="Comma-separated keywords to search for")
    parser.add_argument("--start-date", help="Start date (YYYY-MM-DD format)")
    parser.add_argument("--end-date", help="End date (YYYY-MM-DD format)")
    parser.add_argument("--output-dir", default="./exports", help="Output directory (default: ./exports)")
    parser.add_argument("--list-databases", action="store_true", help="Just list found databases and exit")
    parser.add_argument("--debug", action="store_true", help="Debug mode: only process 5 most recent databases")
    parser.add_argument("--recent-hours", type=int, help="Only search databases modified in the last N hours")
    
    args = parser.parse_args()
    
    # Parse keywords
    keywords = []
    if args.keywords:
        keywords = [k.strip() for k in args.keywords.split(',')]
    
    # Create exporter
    exporter = CursorChatExporter(args.storage_path)
    
    if args.list_databases:
        databases = exporter.find_databases()
        print(f"\nFound {len(databases)} databases:")
        for db in databases:
            info = exporter.extract_workspace_info(db)
            print(f"  {db}")
            print(f"    Workspace ID: {info['workspace_id']}")
            print(f"    Last modified: {info['last_modified']}")
        return
    
    # Export chats
    output_file = exporter.export_chats(
        output_dir=args.output_dir,
        keywords=keywords,
        start_date=args.start_date,
        end_date=args.end_date,
        debug_mode=args.debug,
        recent_hours=args.recent_hours
    )
    
    if output_file:
        print(f"\n✅ Export successful!")
        print(f"📁 Output file: {output_file}")
        print(f"\n💡 Next steps:")
        print(f"1. Review the exported data in {output_file}")
        print(f"2. Use clean_history.js to process and clean the data")
        print(f"3. Refine your search with different keywords if needed")

if __name__ == "__main__":
    main()
