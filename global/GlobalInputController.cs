using GFrameworkGodotTemplate.scripts.core.controller;
using GFrameworkGodotTemplate.scripts.core.state.impls;
using GFrameworkGodotTemplate.scripts.cqrs.game.command;
using GFrameworkGodotTemplate.scripts.cqrs.pause_menu.command.input;
using GFrameworkGodotTemplate.scripts.enums;
using Godot;

namespace GFrameworkGodotTemplate.global;

/// <summary>
///     全局输入控制器类，继承自 GameInputController。
///     负责处理游戏中的全局输入事件，包括暂停和恢复游戏的功能。
/// </summary>
[ContextAware]
[Log]
public partial class GlobalInputController : GameInputController
{
    private UiHandle? _pauseMenuUiHandle;
    private bool _isOpeningPauseMenu;

    /// <summary>
    ///     状态机系统实例，用于管理游戏状态。
    /// </summary>
    private IStateMachineSystem _stateMachineSystem = null!;

    private IUiRouter _uiRouter = null!;

    /// <summary>
    ///     初始化方法，在节点准备就绪时调用。
    ///     获取并初始化状态机系统实例。
    /// </summary>
    public override void _Ready()
    {
        _stateMachineSystem = this.GetSystem<IStateMachineSystem>()!;
        _uiRouter = this.GetSystem<IUiRouter>()!;
        ProcessMode = ProcessModeEnum.Always;
    }

    /// <summary>
    ///     处理未被玩法和 UI 消费的全局确认/取消输入。
    /// </summary>
    public override void _UnhandledInput(InputEvent @event)
    {
        if (TryDispatchCapturedUiAction(@event, "ui_accept", UiInputAction.Confirm))
            return;

        if (!@event.IsActionPressed("ui_cancel"))
            return;

        if (TryDispatchCapturedUiAction(@event, "ui_cancel", UiInputAction.Cancel))
            return;

        if (Tree.Paused || _stateMachineSystem.Current is not PlayingState)
            return;

        if (_isOpeningPauseMenu)
        {
            GetViewport().SetInputAsHandled();
            return;
        }

        _isOpeningPauseMenu = true;
        _log.Debug("暂停游戏");
        OpenPauseMenuAsync().ToCoroutineEnumerator().RunCoroutine(Segment.ProcessIgnorePause);
        GetViewport().SetInputAsHandled();
    }

    private bool TryDispatchCapturedUiAction(InputEvent @event, StringName actionName, UiInputAction action)
    {
        if (!@event.IsActionPressed(actionName) || !_uiRouter.TryDispatchUiAction(action))
            return false;

        GetViewport().SetInputAsHandled();
        return true;
    }

    protected override bool AcceptPhase(InputPhase phase)
    {
        return false;
    }

    protected override void Handle(InputPhase phase, InputEvent @event)
    {
    }

    private async Task OpenPauseMenuAsync()
    {
        try
        {
            _pauseMenuUiHandle = await this.SendAsync(
                new PauseGameWithOpenPauseMenuCommand(new OpenPauseMenuCommandInput
                {
                    Handle = _pauseMenuUiHandle
                })).ConfigureAwait(true);
        }
        finally
        {
            _isOpeningPauseMenu = false;
        }
    }
}
