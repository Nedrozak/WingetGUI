# Winget GUI

This project is a PowerShell script (`winget_gui.ps1`) that provides a graphical user interface (GUI) for managing packages using the Windows Package Manager (`winget`). The GUI is built using XAML and allows users to list upgradable packages, exclude certain packages from being updated, update all upgradable packages, and restore excluded packages.

## Features

- **List Upgradable Packages:** Displays a list of packages that have available updates.
- **Exclude All Packages:** Adds all listed upgradable packages to an exclusion list, preventing them from being updated.
- **Restore Excluded Packages:** Clears the exclusion list, allowing all packages to be updated.
- **Update Upgradable Packages:** Updates all listed upgradable packages.
- **Graphical User Interface:** Provides an intuitive interface for managing packages.

## Prerequisites

- **Windows Package Manager (`winget`)**: Ensure that `winget` is installed and functional on your system.
- **Windows PowerShell**: The script requires Windows PowerShell to run.
- **Administrator Privileges**: Run the script with administrator privileges to allow package management operations.

## Usage

1. Download the project files to your local system.
2. Open PowerShell as an administrator.
3. Navigate to the directory containing `winget_gui.ps1`.
4. Run the script by executing `.\winget_gui.ps1`.
5. Use the GUI to list, exclude, update, and restore packages as needed.

## GUI Overview

The GUI consists of the following components:

- **List Upgradable Packages Button:** Lists packages with available updates.
- **Exclude All Packages Button:** Excludes all listed upgradable packages from updates.
- **Restore Excluded Packages Button:** Restores all excluded packages, allowing updates.
- **ExcludeBox:** Displays the list of excluded packages.
- **Update Upgradable Packages Button:** Updates all listed upgradable packages.
- **OutputListView:** Displays the list of upgradable packages with details such as name, ID, version, and availability.

## Contributing

Contributions to this project are welcome. Feel free to fork the repository, make improvements, and submit pull requests.

## License

This project is licensed under the [MIT License](LICENSE). You are free to modify and distribute the code for both personal and commercial use.

## Acknowledgments

- Special thanks to the developers of `winget` for providing a powerful package management tool for Windows.
- Thanks to the community for feedback and contributions.

## Disclaimer

This script is provided as-is, without any warranty. Use it at your own risk. Always ensure you have proper backups before performing any package management operations.

## Support

For support or inquiries, please [open an issue](https://github.com/yourusername/winget-gui/issues) on GitHub.