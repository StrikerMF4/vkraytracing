#ifndef LOCAL_HELPER
#define LOCAL_HELPER

#include <imgui/imgui_helper.h>


namespace ImGuiH {

class Panelv2: public Panel
{
  static ImGuiID dockspaceID;

public:
  // Starting the panel, equivalent to ImGui::Begin for a window. Need ImGui::end()
  static void Begin(Side side = Side::Right, float alpha = 0.5f, char* name = nullptr, ImGuiWindowFlags flags = 0);
};

}  // namespace ImGuiH


#endif
